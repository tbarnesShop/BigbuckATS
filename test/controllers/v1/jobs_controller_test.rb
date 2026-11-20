# frozen_string_literal: true

require "test_helper"

class V1::JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "JobsCo", slug: "jobs-#{SecureRandom.hex(3)}",
      owner_email: "owner-#{SecureRandom.hex(2)}@jobs.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
  end

  teardown { Current.reset }

  test "index and create" do
    post "/v1/jobs",
         params: { job: { title: "Staff Engineer" } },
         headers: {
           "X-Organization-Id" => @org.id,
           "X-Actor-Id" => @user.id,
           "Idempotency-Key" => "job-#{SecureRandom.hex(4)}"
         },
         as: :json
    assert_response :created
    job_id = response.parsed_body["id"]

    get "/v1/jobs", headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :success
    assert response.parsed_body["data"].any? { |j| j["id"] == job_id }

    get "/v1/jobs/#{job_id}", headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :success
    assert_equal "Staff Engineer", response.parsed_body["title"]
    assert response.parsed_body.dig("pipeline", "stages").is_a?(Array)
    assert response.parsed_body.dig("pipeline", "stages").any?
    assert_equal [], response.parsed_body["dimensions"]
    assert_equal [ "recruiter" ], response.parsed_body["hiring_team"].map { |m| m["role"] }
  end

  test "show reports openings, dimensions, and the hiring team" do
    post "/v1/jobs",
         params: { job: { title: "Platform Engineer" } },
         headers: {
           "X-Organization-Id" => @org.id,
           "X-Actor-Id" => @user.id,
           "Idempotency-Key" => "job-dims-#{SecureRandom.hex(4)}"
         },
         as: :json
    assert_response :created
    job_id = response.parsed_body["id"]

    Current.organization_id = @org.id
    Current.actor_id = @user.id
    department = @provisioned[:dimensions].fetch(:department)
    engineering = DimensionValue.create!(dimension: department, key: "engineering", label: "Engineering")
    EntityDimensionValue.create!(
      entity_type: "Job", entity_id: job_id, dimension: department, dimension_value: engineering
    )
    # The creator is already on the team as recruiter (added on create).

    get "/v1/jobs/#{job_id}", headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :success
    body = response.parsed_body
    assert_equal 1, body["openings"]
    assert_equal false, body["confidential"]
    assert_equal "Engineering", body["dimensions"].first["value"]
    assert_equal "Department", body["dimensions"].first["label"]
    assert_equal "department", body["dimensions"].first["key"]
    assert_equal @user.id, body["hiring_team"].first["user_id"]
    assert_equal "Owner", body["hiring_team"].first["name"]
    assert_equal "recruiter", body["hiring_team"].first["role"]
  end

  test "a new job gets a published posting and its creator on the hiring team" do
    headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    post "/v1/jobs", params: { job: { title: "Product Engineer", careers_visibility: "public" } }, headers: headers, as: :json
    assert_response :created
    body = response.parsed_body
    assert body["careers_published"], "a public job must be on careers without a separate posting step"
    assert_equal [ [ @user.id, "recruiter" ] ], body["hiring_team"].map { |m| [ m["user_id"], m["role"] ] }
    posting = Posting.find_by!(job_id: body["id"])
    assert_equal %w[published public], [ posting.status, posting.audience ]

    post "/v1/jobs", params: { job: { title: "Hidden role", careers_visibility: "hidden" } }, headers: headers, as: :json
    assert_response :created
    assert_not response.parsed_body["careers_published"]
  end

  test "add a hiring team member and list assignable members" do
    headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    post "/v1/jobs", params: { job: { title: "Data Engineer" } }, headers: headers, as: :json
    job_id = response.parsed_body["id"]

    get "/v1/jobs/#{job_id}", headers: headers
    assert_includes response.parsed_body["assignable_members"].map { |m| m["user_id"] }, @user.id

    post "/v1/jobs/#{job_id}/hiring_team/members", params: { user_id: @user.id, team_role: "hiring_manager" }, headers: headers, as: :json
    assert_response :created
    roles = response.parsed_body["hiring_team"].map { |m| m["role"] }.sort
    assert_equal %w[hiring-manager recruiter], roles

    post "/v1/jobs/#{job_id}/hiring_team/members", params: { user_id: @user.id, team_role: "hiring_manager" }, headers: headers, as: :json
    assert_equal 2, response.parsed_body["hiring_team"].size, "adding the same role twice is a no-op"

    post "/v1/jobs/#{job_id}/hiring_team/members", params: { user_id: @user.id, team_role: "boss" }, headers: headers, as: :json
    assert_response :unprocessable_entity
    post "/v1/jobs/#{job_id}/hiring_team/members", params: { user_id: SecureRandom.uuid, team_role: "interviewer" }, headers: headers, as: :json
    assert_response :unprocessable_entity
  end

  def job_headers
    { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
  end

  def create_job(extra = {})
    post "/v1/jobs", params: { job: { title: "Pipeline Eng" }.merge(extra) },
         headers: job_headers.merge("Idempotency-Key" => "job-#{SecureRandom.hex(4)}"), as: :json
    assert_response :created
    response.parsed_body
  end

  test "a new job's pipeline ends in a fixed Hired stage and can be edited" do
    job = create_job
    keys = -> { response.parsed_body.dig("pipeline", "stages").map { |row| row["key"] } }
    assert_equal "hired", job.dig("pipeline", "stages").last["type"]

    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "add_stage", name: "Phone screen", type: "screen" }, headers: job_headers, as: :json
    assert_response :success
    assert_equal %w[applied phone-screen hired], keys.call, "new stages go before Hired"

    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "add_stage", name: "Offer", type: "offer" }, headers: job_headers, as: :json
    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "add_stage", name: "Team chat", type: "interview" }, headers: job_headers, as: :json
    assert_equal %w[applied phone-screen team-chat offer hired], keys.call, "a non-offer stage goes before Offer"
    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "remove_stage", key: "team-chat" }, headers: job_headers, as: :json
    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "remove_stage", key: "offer" }, headers: job_headers, as: :json
    assert_equal %w[applied phone-screen hired], keys.call
    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "rename_stage", key: "phone-screen", name: "Recruiter call" }, headers: job_headers, as: :json
    assert_equal "Recruiter call", response.parsed_body.dig("pipeline", "stages", 1, "name")

    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "move_stage", key: "phone-screen", direction: "up" }, headers: job_headers, as: :json
    assert_response :success
    assert_equal %w[phone-screen applied hired], keys.call

    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "move_stage", key: "applied", direction: "down" }, headers: job_headers, as: :json
    assert_response :unprocessable_entity, "nothing moves below Hired"

    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "remove_stage", key: "hired" }, headers: job_headers, as: :json
    assert_response :unprocessable_entity

    person = Person.create!(display_name: "In Screen", primary_email: "screen-#{SecureRandom.hex(3)}@jobs.test")
    application = ApplicationCreator.call(job: Job.find(job["id"]), person: person)
    assert_equal "phone-screen", application.current_stage_key
    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "remove_stage", key: "phone-screen" }, headers: job_headers, as: :json
    assert_response :unprocessable_entity
    assert_equal "stage_has_candidates", response.parsed_body["title"]

    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "remove_stage", key: "applied" }, headers: job_headers, as: :json
    assert_response :success
    assert_equal %w[phone-screen hired], keys.call
  end

  test "a stage's interview plan can be edited" do
    job = create_job
    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "add_stage", name: "Panel", type: "interview" }, headers: job_headers, as: :json
    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "add_interview", key: "panel", name: "System design", duration_minutes: 60 }, headers: job_headers, as: :json
    assert_response :success
    plan = response.parsed_body.dig("pipeline", "stages").find { |row| row["key"] == "panel" }["interviews"]
    assert_equal [ [ "system-design", "System design", true, 60 ] ], plan.map { |row| row.values_at("key", "name", "required", "duration_minutes") }
    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "remove_interview", key: "panel", interview_key: "system-design" }, headers: job_headers, as: :json
    assert_equal [], response.parsed_body.dig("pipeline", "stages").find { |row| row["key"] == "panel" }["interviews"]
    patch "/v1/jobs/#{job["id"]}/pipeline", params: { op: "add_interview", key: "panel", name: "Bad", rubric_key: "nope" }, headers: job_headers, as: :json
    assert_response :unprocessable_entity
  end

  test "hiring team members can change role and be removed" do
    job = create_job
    other = User.create!(email: "ivy-#{SecureRandom.hex(3)}@jobs.test", name: "Ivy")
    Membership.create!(user: other, role: Role.find_by!(key: "recruiter"), status: "active")
    post "/v1/jobs/#{job["id"]}/hiring_team/members", params: { user_id: other.id, team_role: "hiring_manager" }, headers: job_headers, as: :json
    assert_response :created
    member = response.parsed_body["hiring_team"].find { |row| row["user_id"] == other.id }
    assert_equal "hiring-manager", member["role"], "matches approval policies' role:hiring-manager"

    patch "/v1/jobs/#{job["id"]}/hiring_team/members/#{member["id"]}", params: { team_role: "interviewer" }, headers: job_headers, as: :json
    assert_response :success
    assert_equal "interviewer", response.parsed_body["hiring_team"].find { |row| row["id"] == member["id"] }["role"]

    post "/v1/jobs/#{job["id"]}/hiring_team/members/#{member["id"]}/remove", headers: job_headers, as: :json
    assert_response :success
    refute response.parsed_body["hiring_team"].any? { |row| row["user_id"] == other.id }
  end

  test "a job can be created with a department and a hiring manager from the form options" do
    department = @provisioned[:dimensions][:department]
    design = DimensionValue.create!(dimension: department, key: "design", label: "Design")
    manager = User.create!(email: "hm-#{SecureRandom.hex(2)}@jobs.test", name: "Morgan Manager")
    Membership.create!(user: manager, role: @provisioned[:roles]["hiring_manager"], status: "active")
    read = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }

    get "/v1/jobs/form_options", headers: read
    assert_response :success
    assert_includes response.parsed_body["departments"].map { |d| d["label"] }, "Design"
    assert_includes response.parsed_body["members"].map { |m| m["user_id"] }, manager.id

    post "/v1/jobs",
         params: { job: { title: "Product Designer", department_id: design.id, hiring_manager_user_id: manager.id } },
         headers: read.merge("Idempotency-Key" => "job-hm-#{SecureRandom.hex(4)}"),
         as: :json
    assert_response :created
    body = response.parsed_body
    assert_equal [ "Design" ], body["dimensions"].map { |d| d["value"] }
    roles = body["hiring_team"].to_h { |m| [ m["user_id"], m["role"] ] }
    assert_equal "hiring-manager", roles[manager.id]
    assert_equal "recruiter", roles[@user.id]
  end

  test "a job can be created with a question template" do
    template = ApplicationQuestionTemplate.create!(name: "Eng", owner: @user, status: "active",
      questions: [ { "key" => "github", "label" => "GitHub", "field_type" => "url", "required" => false, "options" => [] } ])
    job = create_job(question_template_id: template.id)
    get "/v1/public/careers/#{@org.slug}"
    row = response.parsed_body["jobs"].find { |item| item["id"] == job["id"] }
    assert_equal [ "GitHub" ], row.dig("application_form", "posting_questions").map { |q| q["label"] }
  end

  test "a job created with a description publishes it on careers" do
    job = create_job(description: "Build the thing.", location: "Remote — US", employment_type: "full_time")
    assert_equal "Build the thing.", job.dig("posting", "description")
    get "/v1/public/careers/#{@org.slug}"
    row = response.parsed_body["jobs"].find { |item| item["id"] == job["id"] }
    assert_equal [ "Build the thing.", "Remote — US", "full_time" ], row.values_at("description", "location", "employment_type")
  end
end
