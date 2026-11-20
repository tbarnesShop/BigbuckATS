require "test_helper"

class V1::PostingQuestionsTest < ActionDispatch::IntegrationTest
  setup do
    @header_auth = Rails.configuration.x.header_auth
    Rails.configuration.x.header_auth = false
    @provisioned = OrganizationProvisioner.call(name: "Forms", slug: "forms-#{SecureRandom.hex(4)}",
      owner_email: "owner-#{SecureRandom.hex(4)}@forms.test", owner_name: "Owner")
    @org, @user = @provisioned.values_at(:organization, :user)
    within_org do
      @token = CredentialIssuer.call(kind: "session", name: "owner", user: @user, audit: false).token
      pipeline = Pipeline.create!(scope: "job", overrides: [], resolved_stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
      @job = Job.create!(title: "Engineer", status: "active", pipeline: pipeline)
      @baseline = CustomField.create!(entity: "application", key: "compliance", label: "Organization compliance", field_type: "boolean", required: true,
        show_on_apply: true, data_class: "sensitive", status: "active", visibility_roles: [])
    end
  end

  teardown do
    Current.reset
    Rails.configuration.x.header_auth = @header_auth
  end

  test "one job exposes multiple independent postings and immutable organization requirements" do
    external = create_posting(title: "External engineer", audience: "public", questions: [ question("why", "External motivation") ])
    internal = create_posting(title: "Internal engineer", audience: "internal", questions: [ question("why", "Internal motivation") ])
    second = create_posting(title: "External senior engineer", audience: "public")
    get "/v1/public/careers/#{@org.slug}"
    assert_equal [ external["id"], second["id"] ].sort, response.parsed_body["jobs"].map { |p| p["posting_id"] }.sort
    get "/v1/internal/careers", headers: bearer
    assert_equal [ internal["id"] ], response.parsed_body["jobs"].map { |p| p["posting_id"] }
    form = response.parsed_body["jobs"].first["application_form"]
    assert_equal [ "compliance" ], form["screening_questions"].map { |q| q["key"] }
    assert_equal [ "posting.why" ], form["posting_questions"].map { |q| q["key"] }
    patch "/v1/postings/#{external['id']}", headers: bearer, params: { posting: { status: "archived", application_form: { required_fields: [] } } }, as: :json
    assert_response :success
    get "/v1/public/careers/#{@org.slug}"
    assert_equal [ second["id"] ], response.parsed_body["jobs"].map { |p| p["posting_id"] }
    assert_equal %w[display_name email], response.parsed_body.dig("application_form", "required_fields")
    get "/v1/internal/careers", headers: bearer
    assert_equal [ internal["id"] ], response.parsed_body["jobs"].map { |p| p["posting_id"] }
  end

  test "templates are reusable owned snapshots refreshed only by explicit selection" do
    template = create_template(questions: [ question("reason", "Template v1") ])
    posting = create_posting(question_template_id: template["id"], questions: [ question("reason", "Local reason") ])
    patch "/v1/application_question_templates/#{template['id']}", headers: bearer,
      params: { question_template: { expected_version: 1, questions: [ question("reason", "Template v2") ] } }, as: :json
    assert_response :success
    patch "/v1/postings/#{posting['id']}", headers: bearer, params: { posting: { title: "Renamed" } }, as: :json
    assert_response :success
    assert_equal "Template v1", response.parsed_body["template_questions"].first["label"]
    assert_equal 1, response.parsed_body["template_version"]
    assert_equal %w[template.reason posting.reason], response.parsed_body.dig("application_form", "posting_questions").map { |q| q["key"] }
    patch "/v1/postings/#{posting['id']}", headers: bearer, params: { posting: { question_template_id: template["id"] } }, as: :json
    assert_response :success
    assert_equal 2, response.parsed_body["template_version"]
    patch "/v1/application_question_templates/#{template['id']}", headers: bearer, params: { question_template: { status: "archived" } }, as: :json
    assert_response :success
    patch "/v1/postings/#{posting['id']}", headers: bearer, params: { posting: { question_template_id: template["id"] } }, as: :json
    assert_response :unprocessable_entity
    patch "/v1/postings/#{posting['id']}", headers: bearer, params: { posting: { title: "Still editable" } }, as: :json
    assert_response :success
    assert_equal "Template v2", response.parsed_body["template_questions"].first["label"]
  end

  test "other recruiters can reuse templates but only owner or admin can edit" do
    recruiter = member_token("recruiter")
    post "/v1/application_question_templates", headers: bearer(recruiter), params: { question_template: { name: "Owned", questions: [] } }, as: :json
    assert_response :created
    template = response.parsed_body
    another = member_token("recruiter")
    get "/v1/application_question_templates", headers: bearer(another)
    assert_response :success
    assert_equal false, response.parsed_body["data"].find { |t| t["id"] == template["id"] }["can_edit"]
    patch "/v1/application_question_templates/#{template['id']}", headers: bearer(another), params: { question_template: { name: "Stolen" } }, as: :json
    assert_response :forbidden
    post "/v1/jobs/#{@job.id}/postings", headers: bearer(another), params: { posting: { title: "Reuse", question_template_id: template["id"] } }, as: :json
    assert_response :created
    patch "/v1/application_question_templates/#{template['id']}", headers: bearer, params: { question_template: { name: "Admin edit" } }, as: :json
    assert_response :success
    readonly = member_token("hiring_manager")
    post "/v1/application_question_templates", headers: bearer(readonly), params: { question_template: { name: "Denied", questions: [] } }, as: :json
    assert_response :forbidden
  end

  test "questions validate and stale writes do not change records" do
    posting = create_posting
    patch "/v1/postings/#{posting['id']}", headers: bearer, params: { posting: { expected_version: 0, title: "Stale" } }, as: :json
    assert_response :conflict
    [ [ question("same"), question("same") ], [ question("bad", "", "text") ], [ question("bad", "Choice", "select") ], [ question("bad", "Unknown", "code") ] ].each do |questions|
      patch "/v1/postings/#{posting['id']}", headers: bearer, params: { posting: { title: "Invalid", questions: questions } }, as: :json
      assert_response :unprocessable_entity
      within_org { assert_equal "Engineer posting", Posting.find(posting["id"]).title }
    end
    template = create_template
    patch "/v1/application_question_templates/#{template['id']}", headers: bearer, params: { question_template: { expected_version: 0, name: "Stale" } }, as: :json
    assert_response :conflict
  end

  test "required baseline and local fields reject without creating people or applications" do
    posting = create_posting(questions: [ question("why", "Why apply?") ])
    [ {}, { "posting.why" => "Reason" }, { "compliance" => false }, { "compliance" => false, "posting.why" => " " },
      { "compliance" => false, "posting.why" => "Reason", "posting.unknown" => "Bad" }, { "compliance" => "Invalid", "posting.why" => "Reason" }, { "compliance" => false, "posting.why" => [ "Wrong shape" ] } ].each do |answers|
      counts = within_org { [ Person.count, Application.count ] }
      apply(posting, answers)
      assert_response :unprocessable_entity
      within_org { assert_equal counts, [ Person.count, Application.count ] }
    end
  end

  test "typed answers persist with posting identity and original labels for review and export" do
    template = create_template(questions: [ question("ready", "Ready?", "boolean") ])
    posting = create_posting(question_template_id: template["id"], questions: [ question("skills", "Skills", "multi_select", options: %w[Ruby TypeScript]), question("years", "Years", "number") ])
    apply(posting, { "compliance" => false, "template.ready" => false, "posting.skills" => %w[Ruby TypeScript], "posting.years" => "3.5" })
    assert_response :created
    app_id = response.parsed_body["application_id"]
    within_org do
      app = Application.find(app_id)
      assert_equal posting["id"], app.posting_id
      assert_equal @job.pipeline_id, app.pipeline_id
      assert_equal [ "organization", "template", "posting", "posting" ], app.application_form_snapshot.map { |q| q["source"] }
      assert_equal({ "compliance" => false, "template.ready" => false, "posting.skills" => %w[Ruby TypeScript], "posting.years" => 3.5 }, app.application_answers)
      packet = AccessPacket.build(person: app.person)
      assert_equal app.application_answers, packet["applications"].first["application_answers"]
    end
    patch "/v1/postings/#{posting['id']}", headers: bearer, params: { posting: { questions: [] } }, as: :json
    assert_response :success
    get "/v1/applications/#{app_id}", headers: bearer
    assert_response :success
    assert_equal "Skills", response.parsed_body["application_form_snapshot"][2]["label"]
    assert_equal %w[Ruby TypeScript], response.parsed_body["application_answers"]["posting.skills"]
    within_org do
      app = Application.find(app_id)
      app.update!(status: "rejected")
      PersonEraser.call(person: app.person)
      assert_nil app.reload.application_answers
      assert_empty PersonEraser.verify(app.person)
      assert_nil CustomFieldValue.find_by!(entity_type: "Application", entity_id: app_id).typed_value
    end
  end

  test "internal submission uses its posting questions and cannot bypass audience" do
    internal = create_posting(audience: "internal", questions: [ question("mobility", "Why move teams?") ])
    apply(internal, { "compliance" => false, "posting.mobility" => "New challenge" })
    assert_response :not_found
    post "/v1/internal/careers/apply/#{internal['id']}", headers: bearer, params: { email: "imposter@forms.test", answers: { "compliance" => false, "posting.mobility" => "New challenge" } }, as: :json
    assert_response :created
    within_org do
      app = Application.find(response.parsed_body["application_id"])
      assert_equal internal["id"], app.posting_id
      assert_equal @user.email, app.person.primary_email
      assert_equal "New challenge", app.application_answers["posting.mobility"]
    end
  end

  test "legacy bulk controls invalidate posting editor versions" do
    posting = create_posting
    patch "/v1/jobs/#{@job.id}", headers: bearer, params: { job: { careers_visibility: "internal" } }, as: :json
    assert_response :success
    patch "/v1/postings/#{posting['id']}", headers: bearer, params: { posting: { expected_version: posting["version"], audience: "public" } }, as: :json
    assert_response :conflict
    within_org { assert_equal "internal", Posting.find(posting["id"]).audience }
  end

  test "posting and template ids cannot cross tenants" do
    other = OrganizationProvisioner.call(name: "Other", slug: "other-#{SecureRandom.hex(4)}", owner_email: "other-#{SecureRandom.hex(4)}@forms.test", owner_name: "Other")
    Current.organization_id = other[:organization].id
    template = ApplicationQuestionTemplate.create!(owner: other[:user], name: "Other template", questions: [])
    pipeline = Pipeline.create!(scope: "job", overrides: [], resolved_stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    job = Job.create!(title: "Other", status: "active", pipeline: pipeline)
    posting = Posting.create!(job: job, title: "Other", audience: "public", status: "published")
    Current.reset
    post "/v1/jobs/#{@job.id}/postings", headers: bearer, params: { posting: { title: "Cross tenant", question_template_id: template.id } }, as: :json
    assert_response :not_found
    patch "/v1/postings/#{posting.id}", headers: bearer, params: { posting: { title: "Cross tenant" } }, as: :json
    assert_response :not_found
    patch "/v1/application_question_templates/#{template.id}", headers: bearer, params: { question_template: { name: "Cross tenant" } }, as: :json
    assert_response :not_found
  end

  private

  def question(key, label = "Question", type = "text", options: [])
    { key: key, label: label, field_type: type, required: true, options: options }
  end

  def create_template(**attrs)
    post "/v1/application_question_templates", headers: bearer, params: { question_template: { name: "Role template", questions: [] }.merge(attrs) }, as: :json
    assert_response :created
    response.parsed_body
  end

  def create_posting(**attrs)
    post "/v1/jobs/#{@job.id}/postings", headers: bearer, params: { posting: { title: "Engineer posting", audience: "public", status: "published", questions: [] }.merge(attrs) }, as: :json
    assert_response :created
    response.parsed_body
  end

  def apply(posting, answers)
    post "/v1/public/careers/#{@org.slug}/apply/#{posting['id']}", params: { display_name: "Applicant", email: "applicant-#{SecureRandom.hex(4)}@forms.test", answers: answers }, as: :json
  end

  def member_token(role)
    within_org do
      user = User.create!(name: "#{role} member", email: "#{role}-#{SecureRandom.hex(4)}@forms.test")
      Membership.create!(user: user, role: @provisioned[:roles].fetch(role), status: "active")
      CredentialIssuer.call(kind: "session", name: role, user: user, audit: false).token
    end
  end

  def bearer(token = @token)
    { "Authorization" => "Bearer #{token}" }
  end

  def within_org
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    yield
  ensure
    Current.reset
  end
end
