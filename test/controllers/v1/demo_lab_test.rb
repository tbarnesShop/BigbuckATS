require "test_helper"

class DemoLabTest < ActionDispatch::IntegrationTest
  setup do
    @enabled = Rails.configuration.x.demo_sign_in
    Rails.configuration.x.demo_sign_in = true
    @result = OrganizationProvisioner.call(name: "Lab", slug: "lab-test-#{SecureRandom.hex(4)}",
      owner_email: "lab-#{SecureRandom.hex(4)}@example.test", owner_name: "Lab Owner")
    @org = @result[:organization]
    @sandbox = DemoSandbox.create!(surface: "tools", organization_id: @org.id, generation: 3,
      state: "ready", seeded_at: Time.current, resets_at: 1.hour.from_now)
    Current.organization_id = @org.id
    @issued = CredentialIssuer.call(kind: "session", name: "test", user: @result[:user], expires_at: 1.hour.from_now)
    @person = Person.create!(display_name: "Keep me", primary_email: "keep@example.test", lifecycle_stage: "candidate")
    Current.reset
    @headers = { "Authorization" => "Bearer #{@issued.token}", "X-Bigbuck-Demo-Generation" => "3" }
  end

  teardown do
    Rails.configuration.x.demo_sign_in = @enabled
    Current.reset
  end

  test "Owner can create and duplicate submissions reuse persisted results" do
    headers = @headers.merge("Idempotency-Key" => "lab-create")
    2.times do
      post "/v1/people", params: { person: { display_name: "New", email: "new@example.test" } }, headers: headers, as: :json
      assert_response :created
    end
    assert_equal 1, Person.unscoped.where(organization_id: @org.id, primary_email: "new@example.test").count
  end

  test "permission inspector reports current boundaries without revealing bearer tokens" do
    get "/demo/permissions", headers: @headers
    assert_response :success
    body = response.parsed_body
    assert_equal "owner", body.dig("membership", "role_key")
    assert_equal "user", body["actor_type"]
    assert_includes body["permissions"], "person.create"
    assert_equal @sandbox.generation, body.dig("sandbox", "generation")
    assert_kind_of Array, body["role_permissions"]
    assert_kind_of Array, body["credential_scopes"]
    refute_includes response.body, @issued.token
  end

  test "permission inspector requires a registered demo principal" do
    @sandbox.destroy!
    get "/demo/permissions", headers: @headers
    assert_response :forbidden
    assert_equal "demo_session_required", response.parsed_body["code"]
  end

  test "Owner direct REST erasure and archive payloads are denied" do
    post "/v1/people/#{@person.id}/erase", headers: @headers, as: :json
    assert_response :forbidden
    assert_equal "demo_action_blocked", response.parsed_body["code"]
    patch "/v1/people/#{@person.id}", params: { person: { lifecycle_stage: "archived" } }, headers: @headers, as: :json
    assert_response :forbidden
    assert_nil @person.reload.erased_at
  end

  test "GraphQL destructive mutations are denied before domain changes" do
    Current.organization_id = @org.id
    issued = CredentialIssuer.call(kind: "personal", name: "GraphQL", user: @result[:user], scopes: Scopes::ALL)
    Current.reset
    post "/graphql", params: { query: 'mutation { archiveCustomField(input: {id: "missing"}) { userErrors { code } } }' }, headers: @headers.merge("Authorization" => "Bearer #{issued.token}"), as: :json
    assert_response :success
    assert_equal "demo_action_blocked", response.parsed_body.dig("errors", 0, "extensions", "code")
  end

  test "data request fulfilment cannot hide destructive actions" do
    post "/v1/applications/missing/transitions", params: { transition: { command: "reject", reason: "sample", mode: "erase" } }, headers: @headers, as: :json
    assert_response :forbidden, "an archive command cannot smuggle another blocked value"
    assert_equal "demo_action_blocked", response.parsed_body["code"]
    Current.organization_id = @org.id
    request = ComplianceDesk.open_request!(kind: "erasure", requester_email: "keep@example.test", person: @person)
    Current.reset
    post "/v1/data_requests/#{request.id}/complete", headers: @headers, as: :json
    assert_response :forbidden
    assert_nil @person.reload.erased_at
    assert_equal "open", request.reload.status
  end

  test "identity overrides and the legacy harness cannot bypass demo credentials" do
    post "/v1/credentials", params: { credential: { name: "escape", kind: "integration", scopes: [ "people:write" ] } }, headers: @headers, as: :json
    assert_response :forbidden
    get "/v1/people", headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @result[:user].id }
    assert_response :forbidden
    assert_equal "demo_requires_bearer", response.parsed_body["code"]
  end

  test "stale generations explicitly require restart" do
    get "/v1/people", headers: @headers.merge("X-Bigbuck-Demo-Generation" => "2")
    assert_response :conflict
    assert_equal "sandbox_expired", response.parsed_body["code"]
  end

  test "a credential cannot retarget a different organization" do
    get "/v1/people", headers: @headers.merge("X-Organization-Id" => SecureRandom.uuid)
    assert_response :forbidden
    assert_equal "organization_mismatch", response.parsed_body["code"]
  end

  test "named locks acquire and release even inside the query cache" do
    ActiveRecord::Base.connection.cache do
      3.times { DemoWorkspaces.lock("api") { assert true } }
      assert_nil ActiveRecord::Base.connection.uncached { ActiveRecord::Base.connection.select_value("SELECT IS_USED_LOCK(#{ActiveRecord::Base.connection.quote(DemoWorkspaces.lock_name("api"))})") }
    end
  end

  test "a lab owner can take someone off a job's hiring team, but not delete the job's records" do
    Current.organization_id = @org.id
    template = PipelineTemplate.create!(key: "lab-#{SecureRandom.hex(2)}", name: "Lab", object_type: "job")
    template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    job = Job.create!(title: "Lab job", status: "active", pipeline: Pipeline.build_from_template!(template: template))
    member = HiringTeam.create!(job: job).members.create!(user: @result[:user], team_role: "interviewer")
    Current.reset
    post "/v1/jobs/#{job.id}/hiring_team/members/#{member.id}/remove", headers: @headers, as: :json
    assert_response :success
    assert_not HiringTeamMember.unscoped.exists?(id: member.id)
    post "/v1/jobs/#{job.id}/remove", headers: @headers, as: :json
    assert_includes [ 403, 404 ], response.status, "the exemption is one named action, not the word"
  end

  def lab_application
    Current.organization_id = @org.id
    template = PipelineTemplate.create!(key: "arch-#{SecureRandom.hex(2)}", name: "Lab", object_type: "job")
    template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    job = Job.create!(title: "Lab job", status: "active", pipeline: Pipeline.build_from_template!(template: template))
    app = ApplicationCreator.call(job: job, person: @person)
    Current.reset
    app
  end

  test "a lab persona can archive an application with a reason, and the person stays" do
    app = lab_application
    post "/v1/applications/#{app.id}/transitions", params: { transition: { command: "reject", reason: "Not a fit" } },
      headers: @headers.merge("Idempotency-Key" => "arch-#{SecureRandom.hex(3)}"), as: :json
    assert_response :created
    assert_equal "rejected", app.reload.status
    assert_nil @person.reload.erased_at
    patch "/v1/people/#{@person.id}", params: { person: { lifecycle_stage: "archived" } }, headers: @headers, as: :json
    assert_response :forbidden, "archiving the person record is still blocked"
  end

  test "candidate apply and offer answers follow the deployment setting" do
    Current.organization_id = @org.id
    template = PipelineTemplate.create!(key: "cand-#{SecureRandom.hex(2)}", name: "Lab", object_type: "job")
    template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    job = Job.create!(title: "Open role", status: "active", pipeline: Pipeline.build_from_template!(template: template))
    posting = job.postings.create!(title: "Open role", audience: "public", status: "published")
    Current.reset
    applicant = { display_name: "Pat Public", email: "pat-#{SecureRandom.hex(3)}@example.test" }

    post "/v1/public/careers/#{@org.slug}/apply/#{posting.id}", params: applicant, as: :json
    assert_response :forbidden
    assert_equal "demo_candidate_action_blocked", response.parsed_body["code"]

    previous = Rails.configuration.x.demo_candidate_writes
    Rails.configuration.x.demo_candidate_writes = true
    begin
      get "/v1/public/careers/#{@org.slug}"
      assert response.parsed_body.dig("careers", "accepts_applications")
      post "/v1/public/careers/#{@org.slug}/apply/#{posting.id}", params: applicant, as: :json
      assert_response :created
      stored = Application.unscoped.find(response.parsed_body["application_id"])
      assert_equal [ job.id, @org.id, "Pat Public" ], [ stored.job_id, stored.organization_id, Person.unscoped.find(stored.person_id).display_name ],
        "the external application is in the database"
    ensure
      Rails.configuration.x.demo_candidate_writes = previous
    end
  end

  test "configuration cannot archive existing objects indirectly" do
    Current.organization_id = @org.id
    plan = ConfigPlan.create!(status: "open", desired_manifest: { "test" => true }, manifest_hash: "test", object_versions: {}, change_set: [ { "op" => "archive", "kind" => "PipelineTemplate", "key" => "keep" } ])
    assert_raises(Authenticator::Forbidden) { ConfigApplier.apply!(plan) }
    assert_equal "open", plan.reload.status
  end

  test "preparing a ready sandbox does not need the sandbox lock" do
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    other = Mysql2::Client.new(host: config[:host], port: config[:port], username: config[:username],
      password: config[:password], database: config[:database], socket: config[:socket])
    lock = ActiveRecord::Base.connection.quote(DemoWorkspaces.lock_name(@sandbox.surface))
    other.query("SELECT GET_LOCK(#{lock}, 0)")
    begin
      assert_equal @sandbox.organization_id, DemoWorkspaces.prepare!("api").organization_id,
        "a second persona signing in at the same moment must not fail as sandbox_busy"
    ensure
      other.query("SELECT RELEASE_LOCK(#{lock})")
      other.close
    end
  end

  test "requests to a ready sandbox do not wait on the sandbox lock" do
    # A separate MySQL session: transactional tests share one pooled connection, and GET_LOCK is
    # re-entrant within a session, so the pool cannot stand in for "another request".
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    other = Mysql2::Client.new(host: config[:host], port: config[:port], username: config[:username],
      password: config[:password], database: config[:database], socket: config[:socket])
    lock = ActiveRecord::Base.connection.quote(DemoWorkspaces.lock_name(@sandbox.surface))
    assert_equal 1, other.query("SELECT GET_LOCK(#{lock}, 0) AS got").first["got"].to_i
    begin
      get "/v1/people", headers: @headers
      assert_response :success, "a parallel request (another section of the same page) must not fail as sandbox_busy"
    ensure
      other.query("SELECT RELEASE_LOCK(#{lock})")
      other.close
    end
  end
end

class DemoResetTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "reset replaces only its registered tenant and invalidates old credentials" do
    other = OrganizationProvisioner.call(name: "Other", slug: "other-#{SecureRandom.hex(4)}",
      owner_email: "other-#{SecureRandom.hex(4)}@example.test", owner_name: "Other")
    sandbox = DemoWorkspaces.prepare!("ui")
    old_id = sandbox.organization_id
    Current.organization_id = old_id
    owner = Membership.includes(:user, :role).find_by!(role: Role.find_by!(key: "owner")).user
    issued = CredentialIssuer.call(kind: "session", name: "old", user: owner)
    Current.reset
    generation = sandbox.generation
    DemoWorkspaces.lock("ui") { DemoWorkspaces.refresh!(sandbox) }
    assert_equal generation + 1, sandbox.reload.generation
    refute_equal old_id, sandbox.organization_id
    assert_nil ApiCredential.find_bearer(issued.token)
    assert_nil Organization.find_by(id: old_id)
    assert Organization.find(other[:organization].id)
    assert_equal 100, Person.unscoped.where(organization_id: sandbox.organization_id).count
  end

  test "outbound adapters capture sample effects before contacting providers" do
    provisioned = OrganizationProvisioner.call(name: "Capture", slug: "capture-#{SecureRandom.hex(4)}",
      owner_email: "capture-#{SecureRandom.hex(4)}@example.test", owner_name: "Capture")
    org = provisioned[:organization]
    DemoSandbox.create!(surface: "tools", organization_id: org.id, generation: 1, state: "ready", seeded_at: Time.current, resets_at: 1.hour.from_now)
    Current.organization_id = org.id
    mailbox = Struct.new(:organization_id, :email).new(org.id, "sample@example.test")
    assert GmailClient.send_message!(mailbox: mailbox, to: "sample@example.test", subject: "Sample", body: "Sample")[:captured]
    assert CalendarClient.create_event!(organizer_calendar: "sample", starts_at: Time.current, ends_at: 1.hour.from_now, attendee_emails: [], summary: "Sample")[:captured]
  end

  test "retire_legacy! drops the old per-surface sandbox rows and their tenants" do
    provisioned = OrganizationProvisioner.call(name: "Legacy", slug: "legacy-#{SecureRandom.hex(4)}",
      owner_email: "legacy-#{SecureRandom.hex(4)}@example.test", owner_name: "Legacy")
    legacy_org = provisioned[:organization]
    now = Time.current
    DemoSandbox.insert_all([ { surface: "mcp", organization_id: legacy_org.id, state: "ready", generation: 1,
                               created_at: now, updated_at: now } ])
    DemoWorkspaces.retire_legacy!
    assert_not DemoSandbox.exists?(surface: "mcp")
    assert_not Organization.unscoped.exists?(id: legacy_org.id)
  end

  test "mcp, api and cli share the tools sandbox" do
    assert_equal %w[tools tools tools ui], %w[mcp api cli ui].map { |surface| DemoSandbox.sandbox_for(surface) }.sort
  end
end
