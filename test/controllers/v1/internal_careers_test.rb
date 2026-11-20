require "test_helper"

class V1::InternalCareersTest < ActionDispatch::IntegrationTest
  setup do
    @header_auth = Rails.configuration.x.header_auth
    Rails.configuration.x.header_auth = false
    provisioned = OrganizationProvisioner.call(
      name: "Mobility", slug: "mobility-#{SecureRandom.hex(4)}",
      owner_email: "owner-#{SecureRandom.hex(4)}@mobility.test", owner_name: "Employee"
    )
    @org, @user, @membership = provisioned.values_at(:organization, :user, :membership)
    Current.organization_id = @org.id
    @token = CredentialIssuer.call(kind: "session", name: "employee", user: @user, audit: false).token
    template = PipelineTemplate.create!(key: "mobility", name: "Mobility", object_type: "job")
    template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    @jobs = %w[public internal both hidden].to_h do |visibility|
      job = Job.create!(title: "#{visibility} role", status: "active", careers_visibility: visibility,
                        pipeline: Pipeline.build_from_template!(template: template))
      Posting.create!(job: job, title: job.title, status: "published")
      [ visibility, job ]
    end
    @draft = Job.create!(title: "Unpublished", status: "active", pipeline: @jobs["public"].pipeline)
    Posting.create!(job: @draft, title: @draft.title)
    Current.reset
  end

  teardown do
    Rails.configuration.x.header_auth = @header_auth
    Current.reset
  end

  test "public and internal listings respect audience publication and confidentiality" do
    get "/v1/public/careers/#{@org.slug}"
    assert_response :success
    assert_equal %w[both public], response.parsed_body["jobs"].map { |job| job["title"].split.first }.sort
    get "/v1/internal/careers", headers: bearer
    assert_response :success
    assert_equal %w[both internal], response.parsed_body["jobs"].map { |job| job["title"].split.first }.sort
    assert_equal "private, no-store", response.headers["Cache-Control"]
    within_org { @jobs["both"].update!(confidential: true, code_name: "Secret") }
    get "/v1/internal/careers", headers: bearer
    assert_equal [ @jobs["internal"].id ], response.parsed_body["jobs"].map { |job| job["id"] }
    get "/v1/public/careers/#{@org.slug}"
    assert_equal [ @jobs["public"].id ], response.parsed_body["jobs"].map { |job| job["id"] }
  end

  test "internal careers requires a human active member and ignores organization query parameters" do
    get "/v1/internal/careers", headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :unauthorized
    integration = within_org { CredentialIssuer.call(kind: "integration", name: "test", scopes: %w[jobs:read], audit: false) }
    get "/v1/internal/careers", headers: { "Authorization" => "Bearer #{integration.token}" }
    assert_response :forbidden
    agent = within_org { Agent.create!(owner_membership: @membership, name: "Bot", scopes: %w[jobs:read]) }
    get "/v1/internal/careers", headers: bearer.merge("X-Bigbuck-Act-As-Agent" => agent.id)
    assert_response :forbidden
    get "/v1/internal/careers?slug=another-org", headers: bearer
    assert_response :success
    assert_equal @org.id, response.parsed_body.dig("organization", "id")
    within_org { @membership.update!(status: "inactive") }
    get "/v1/internal/careers", headers: bearer
    assert_response :forbidden
  end

  test "internal application uses employee identity and the existing job pipeline" do
    posting = within_org { @jobs["internal"].postings.first }
    post "/v1/internal/careers/apply/#{posting.id}", headers: bearer,
         params: { posting_id: "wrong", display_name: "Imposter", email: "imposter@example.test",
                   answers: { "display_name" => "Imposter", "email" => "imposter@example.test" } }, as: :json
    assert_response :created
    within_org do
      application = Application.find(response.parsed_body["application_id"])
      assert_equal @jobs["internal"].id, application.job_id
      assert_equal @jobs["internal"].pipeline_id, application.pipeline_id
      assert_equal "applied", application.current_stage_key
      assert_equal @user.email, application.person.primary_email
      assert_equal @user.name, application.person.display_name
    end
  end

  test "direct apply cannot bypass audience status confidentiality or publication" do
    %w[internal hidden].each do |visibility|
      posting = within_org { @jobs[visibility].postings.first }
      post "/v1/public/careers/#{@org.slug}/apply/#{posting.id}", params: applicant, as: :json
      assert_response :not_found
    end
    posting = within_org { @jobs["public"].postings.first }
    post "/v1/internal/careers/apply/#{posting.id}", headers: bearer, params: applicant, as: :json
    assert_response :not_found
    %w[paused closed archived].each do |status|
      within_org { @jobs["both"].update!(status: status) }
      both_posting = within_org { @jobs["both"].postings.first }
      post "/v1/internal/careers/apply/#{both_posting.id}", headers: bearer, params: applicant, as: :json
      assert_response :not_found
    end
    draft_posting = within_org { @draft.postings.first }
    post "/v1/public/careers/#{@org.slug}/apply/#{draft_posting.id}", params: applicant, as: :json
    assert_response :unprocessable_entity
    within_org { @jobs["public"].update!(confidential: true, code_name: "Secret") }
    post "/v1/public/careers/#{@org.slug}/apply/#{posting.id}", params: applicant, as: :json
    assert_response :not_found
  end

  test "a member cannot apply to another organization's posting" do
    other = OrganizationProvisioner.call(name: "Other", slug: "other-#{SecureRandom.hex(4)}",
      owner_email: "other-#{SecureRandom.hex(4)}@mobility.test", owner_name: "Other")
    Current.organization_id = other[:organization].id
    pipeline = Pipeline.create!(scope: "job", overrides: [], resolved_stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    job = Job.create!(title: "Other internal role", status: "active", careers_visibility: "internal", pipeline: pipeline)
    posting = Posting.create!(job: job, title: job.title, status: "published")
    Current.reset
    post "/v1/internal/careers/apply/#{posting.id}", headers: bearer, params: applicant, as: :json
    assert_response :not_found
  end

  test "job settings publish unpublish validate and roll back atomically" do
    patch "/v1/jobs/#{@draft.id}", headers: bearer,
      params: { job: { careers_visibility: "internal", careers_published: true, openings: 2 } }, as: :json
    assert_response :success
    assert_equal "internal", response.parsed_body["careers_visibility"]
    assert_equal true, response.parsed_body["careers_published"]
    get "/v1/internal/careers", headers: bearer
    assert_includes response.parsed_body["jobs"].map { |j| j["id"] }, @draft.id
    patch "/v1/jobs/#{@draft.id}", headers: bearer,
      params: { job: { careers_published: false } }, as: :json
    assert_response :success
    assert_equal false, response.parsed_body["careers_published"]
    patch "/v1/jobs/#{@draft.id}", headers: bearer,
      params: { job: { careers_visibility: "invalid", careers_published: true } }, as: :json
    assert_response :unprocessable_entity
    within_org do
      assert_equal "internal", @draft.reload.careers_visibility
      refute @draft.postings.exists?(status: "published")
      @draft.update!(status: "paused")
    end
    patch "/v1/jobs/#{@draft.id}", headers: bearer,
      params: { job: { careers_visibility: "both", careers_published: true } }, as: :json
    assert_response :unprocessable_entity
    within_org { assert_equal "internal", @draft.reload.careers_visibility }
    patch "/v1/jobs/#{@draft.id}", headers: bearer,
      params: { job: { careers_published: "false" } }, as: :json
    assert_response :unprocessable_entity
  end

  private

  def bearer
    { "Authorization" => "Bearer #{@token}" }
  end

  def applicant
    { display_name: "Applicant", email: "applicant@example.test" }
  end

  def within_org
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    yield
  ensure
    Current.reset
  end
end
