# frozen_string_literal: true

require "test_helper"

class V1::ApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "AppsCo", slug: "apps-#{SecureRandom.hex(3)}",
      owner_email: "owner-#{SecureRandom.hex(2)}@apps.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    template = PipelineTemplate.create!(key: "default", name: "Default", object_type: "job")
    template.publish!(stages: [
      { "key" => "applied", "name" => "Applied", "type" => "apply" },
      { "key" => "onsite", "name" => "Onsite", "type" => "interview" },
      { "key" => "offer", "name" => "Offer", "type" => "offer" }
    ])
    @pipeline = Pipeline.build_from_template!(template: template)
    @job = Job.create!(title: "Backend", status: "active", pipeline: @pipeline)
    @person = Person.create!(display_name: "Cand One", primary_email: "c1@apps.test")
  end

  teardown { Current.reset }

  test "create and list by job" do
    post "/v1/applications",
         params: { application: { job_id: @job.id, person_id: @person.id } },
         headers: {
           "X-Organization-Id" => @org.id,
           "X-Actor-Id" => @user.id,
           "Idempotency-Key" => "app-#{SecureRandom.hex(4)}"
         },
         as: :json
    assert_response :created
    app_id = response.parsed_body["id"]
    assert_equal "Cand One", response.parsed_body.dig("person", "display_name")
    assert_equal "Backend", response.parsed_body.dig("job", "title")
    stages = response.parsed_body.dig("pipeline", "stages")
    assert_equal 4, stages.size, "three template stages plus the system Hired stage"
    assert_equal "hired", stages.last["type"]

    get "/v1/applications",
        params: { job_id: @job.id },
        headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :success
    assert response.parsed_body["data"].any? { |a| a["id"] == app_id }

    get "/v1/applications",
        params: { person_id: @person.id },
        headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :success
    assert_equal 1, response.parsed_body["data"].size
  end

  test "move stage via transitions and list history" do
    application = ApplicationCreator.call(job: @job, person: @person)

    post "/v1/applications/#{application.id}/transitions",
         params: { to_stage_key: "onsite", reason: "panel ready" },
         headers: {
           "X-Organization-Id" => @org.id,
           "X-Actor-Id" => @user.id,
           "Idempotency-Key" => "move-#{SecureRandom.hex(4)}"
         },
         as: :json
    assert_response :created
    assert_equal "onsite", response.parsed_body["current_stage_key"]

    get "/v1/applications/#{application.id}/transitions",
        headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :success
    move = response.parsed_body["data"].find { |t| t["command"] == "move" }
    assert_equal "applied", move["from_stage_key"]
    assert_equal "onsite", move["to_stage_key"]
    assert_equal "panel ready", move["reason"]
  end

  test "reject via transitions command" do
    application = ApplicationCreator.call(job: @job, person: @person)

    post "/v1/applications/#{application.id}/transitions",
         params: { command: "reject", reason: "not a fit" },
         headers: {
           "X-Organization-Id" => @org.id,
           "X-Actor-Id" => @user.id,
           "Idempotency-Key" => "reject-#{SecureRandom.hex(4)}"
         },
         as: :json
    assert_response :created
    assert_equal "rejected", response.parsed_body["status"]
  end

  test "the archived filter lists rejected and withdrawn applications with their reason" do
    headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    Current.organization_id = @org.id
    archived = ApplicationCreator.call(job: @job, person: Person.create!(display_name: "Gone", primary_email: "gone-#{SecureRandom.hex(3)}@x.test"))
    SubjectTransitions.reject(subject: archived, reason: "Role filled")
    active = ApplicationCreator.call(job: @job, person: Person.create!(display_name: "Here", primary_email: "here-#{SecureRandom.hex(3)}@x.test"))
    Current.reset
    get "/v1/applications", params: { status: "archived", page: 1 }, headers: headers
    assert_response :success
    ids = response.parsed_body["data"].map { |row| row["id"] }
    assert_includes ids, archived.id
    refute_includes ids, active.id
    assert_equal "Role filled", response.parsed_body["data"].find { |row| row["id"] == archived.id }["closed_reason"]
  end

  test "candidates with planned but unbooked interviews are waiting to be scheduled" do
    Current.organization_id = @org.id
    template = PipelineTemplate.create!(key: "panel-#{SecureRandom.hex(2)}", name: "Panel", object_type: "job")
    template.publish!(stages: [ { "key" => "panel", "name" => "Panel", "type" => "interview",
      "interviews" => [ { "key" => "craft", "name" => "Craft", "required" => true }, { "key" => "values", "name" => "Values", "required" => true } ] } ])
    job = Job.create!(title: "Designer", status: "active", pipeline: Pipeline.build_from_template!(template: template))
    app = ApplicationCreator.call(job: job, person: @person)
    Interview.create!(application: app, stage_key: "panel", interview_key: "craft", status: "scheduled", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour, interviewer_user_ids: [ @user.id ])
    Current.reset
    get "/v1/interviews/awaiting_schedule", headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :success
    row = response.parsed_body["data"].find { |item| item["application_id"] == app.id }
    assert_equal [ "values" ], row["missing"].map { |item| item["key"] }, "booked interviews are not listed again"
    assert_equal "Panel", row.dig("stage", "name")
  end
end
