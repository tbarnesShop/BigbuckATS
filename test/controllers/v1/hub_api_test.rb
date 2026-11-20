# frozen_string_literal: true

require "test_helper"

class V1::HubApiTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "HubCo", slug: "hub-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@hub.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    GoogleSignIn.verify_domain!(domain: "hub.test")

    template = PipelineTemplate.create!(key: "hub", name: "Hub", object_type: "job")
    template.publish!(stages: [
      { "key" => "applied", "name" => "Applied", "type" => "apply" },
      { "key" => "onsite", "name" => "Onsite", "type" => "interview" }
    ])
    @pipeline = Pipeline.build_from_template!(template: template)
    @job = Job.create!(title: "Backend", status: "active", pipeline: @pipeline, openings: 2)
    @person = Person.create!(display_name: "Pat Example", primary_email: "pat@example.com")
    @application = ApplicationCreator.call(job: @job, person: @person)
  end

  teardown { Current.reset }

  def headers
    { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id, "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }
  end

  def posting_for(job, status: "published", title: nil)
    Posting.create!(job: job, title: title || job.title, status: status)
  end

  test "applications filter by status and stage across jobs" do
    other = Person.create!(display_name: "Other", primary_email: "other@example.com")
    moved = ApplicationCreator.call(job: @job, person: other)
    SubjectTransitions.move(subject: moved, to_stage_key: "onsite", reason: "panel")
    SubjectTransitions.reject(subject: @application, reason: "no")

    get "/v1/applications", params: { status: "rejected" }, headers: headers
    assert_response :success
    assert_equal [ @application.id ], response.parsed_body["data"].map { |row| row["id"] }

    get "/v1/applications", params: { stage: "onsite", status: "active" }, headers: headers
    assert_response :success
    assert_equal [ moved.id ], response.parsed_body["data"].map { |row| row["id"] }

    get "/v1/applications", params: { status: "nope" }, headers: headers
    assert_response :unprocessable_entity
    assert_equal "invalid_filter", response.parsed_body["code"]
  end

  test "offers list filters by status and returns counts for the unfiltered set" do
    draft = Offer.create!(application: @application, status: "draft", version: 1)
    other = Person.create!(display_name: "Other", primary_email: "other-offer@example.com")
    other_app = ApplicationCreator.call(job: @job, person: other)
    Offer.create!(application: other_app, status: "pending_approval", version: 1)

    get "/v1/offers", params: { status: "draft" }, headers: headers
    assert_response :success
    assert_equal [ draft.id ], response.parsed_body["data"].map { |row| row["id"] }
    assert_equal 1, response.parsed_body.dig("counts", "draft")
    assert_equal 1, response.parsed_body.dig("counts", "pending_approval")
    assert_equal 0, response.parsed_body.dig("counts", "sent")

    get "/v1/offers", params: { status: "nope" }, headers: headers
    assert_response :unprocessable_entity
    assert_equal "invalid_filter", response.parsed_body["code"]
  end

  test "today returns ids for feedback, reviews, upcoming, offers and jobs" do
    # One already held (feedback owed) and one still to come (upcoming, nothing owed yet).
    Interview.create!(
      application: @application, stage_key: "onsite", interview_key: "screen", status: "completed",
      starts_at: 2.hours.ago, ends_at: 1.hour.ago, interviewer_user_ids: [ @user.id ]
    )
    Interview.create!(
      application: @application, stage_key: "onsite", interview_key: "hm", status: "scheduled",
      starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour, interviewer_user_ids: [ @user.id ]
    )
    Offer.create!(application: @application, status: "pending_approval", version: 1)

    get "/v1/today", headers: headers
    assert_response :success
    body = response.parsed_body
    assert_equal [ @application.id ], body["reviews"].map { |row| row["application_id"] }
    assert_equal 1, body["feedback"].size
    assert_equal 1, body["upcoming"].size
    assert_equal 1, body["offers_pending"].size
    job = body["jobs"].find { |row| row["id"] == @job.id }
    assert_equal 2, job["openings"]
    assert_equal 1, job["active_count"]
    assert_nil body["feedback"].first["person_name"]
    assert_nil body["offers_pending"].first["person_name"]
  end

  test "calendar connect rejects an unverified domain and stays pending without a real grant" do
    post "/v1/calendar_connections",
         params: { calendar_connection: { calendar_id: "ops@evil.test", secret_ref: "sm://real" } },
         headers: headers, as: :json
    assert_response :unprocessable_entity
    assert_equal "unverified_domain", response.parsed_body["code"]

    post "/v1/calendar_connections",
         params: { calendar_connection: { calendar_id: "domain:evil.test" } },
         headers: headers, as: :json
    assert_response :unprocessable_entity

    post "/v1/calendar_connections",
         params: { calendar_connection: { calendar_id: "ada@hub.test", secret_ref: "sm://demo" } },
         headers: headers, as: :json
    assert_response :created
    assert_equal "pending", response.parsed_body["status"]
    refute response.parsed_body.key?("secret_ref")

    post "/v1/calendar_connections",
         params: { calendar_connection: { calendar_id: "ada@hub.test", secret_ref: "sm://real-grant" } },
         headers: headers, as: :json
    assert_response :created
    assert_equal "connected", response.parsed_body["status"]
    refute response.parsed_body.key?("secret_ref")

    Current.organization_id = @org.id
    assert_equal "sm://real-grant", CalendarConnection.order(:created_at).last.secret_ref
  end

  test "scorecard rubrics can be listed and refuse a duplicate key" do
    post "/v1/scorecard_rubrics",
         params: {
           scorecard_rubric: {
             key: "screen", name: "Screen",
             attributes_spec: [ { key: "communication", label: "Communication", required: true } ]
           }
         },
         headers: headers, as: :json
    assert_response :created
    assert_equal [ "communication" ], response.parsed_body["attributes_spec"].map { |row| row["key"] }

    get "/v1/scorecard_rubrics", headers: headers
    assert_response :success
    assert_equal [ "screen" ], response.parsed_body["data"].map { |row| row["key"] }

    post "/v1/scorecard_rubrics",
         params: { scorecard_rubric: { key: "screen", name: "Again", attributes_spec: [ { key: "a" } ] } },
         headers: headers, as: :json
    assert_response :unprocessable_entity
  end

  test "application form screening field ids toggle show_on_apply" do
    roast = CustomFieldDefinitions.create!(entity: "application", key: "roast", label: "Roast", field_type: "text")
    other = CustomFieldDefinitions.create!(entity: "application", key: "source", label: "Source", field_type: "text", show_on_apply: true)

    patch "/v1/application_form",
          params: { application_form: { required_fields: %w[display_name email], screening_field_ids: [ roast.id ] } },
          headers: headers, as: :json
    assert_response :success
    assert_equal [ "roast" ], response.parsed_body["screening_questions"].map { |row| row["key"] }

    Current.organization_id = @org.id
    assert roast.reload.show_on_apply
    refute other.reload.show_on_apply
  end

  test "only application fields can show on the careers form" do
    post "/v1/custom_fields",
         params: { custom_field: { entity: "person", key: "hobby", label: "Hobby", field_type: "text", show_on_apply: true } },
         headers: headers, as: :json
    assert_response :unprocessable_entity
    assert_equal "show_on_apply_entity", response.parsed_body["code"]
  end

  test "public apply uses the path posting, required fields, and screening answers" do
    roast = CustomFieldDefinitions.create!(
      entity: "application", key: "roast", label: "Roast", field_type: "text", required: true, show_on_apply: true
    )
    hidden = CustomFieldDefinitions.create!(
      entity: "application", key: "band", label: "Band", field_type: "text",
      show_on_apply: true, visibility_roles: [ "admin" ]
    )
    posting = posting_for(@job)

    get "/v1/public/careers/#{@org.slug}"
    assert_response :success
    body = response.parsed_body
    assert_equal %w[display_name email], body.dig("application_form", "required_fields")
    assert_equal [ "roast" ], body.dig("application_form", "screening_questions").map { |row| row["key"] }
    job = body["jobs"].find { |row| row["id"] == @job.id }
    assert_equal posting.id, job["posting_id"]
    assert_equal 2, job["openings"]

    Current.organization_id = @org.id
    other = posting_for(@job, title: "Other")
    post "/v1/public/careers/#{@org.slug}/apply/#{posting.id}",
         params: { posting_id: other.id, answers: { display_name: "Pat Example", roast: "medium" } },
         as: :json
    assert_response :unprocessable_entity
    assert_match(/missing_fields:email/, response.parsed_body["title"])

    post "/v1/public/careers/#{@org.slug}/apply/#{posting.id}",
         params: {
           posting_id: other.id,
           answers: { display_name: "Pat Example", email: "pat@example.com", roast: "medium", band: "L5" }
         },
         as: :json
    assert_response :created
    assert_equal posting.id, response.parsed_body["posting_id"]
    application_id = response.parsed_body["application_id"]

    Current.organization_id = @org.id
    stored = CustomFieldValue.where(entity_type: "Application", entity_id: application_id).includes(:custom_field)
    assert_equal [ "roast" ], stored.map { |row| row.custom_field.key }
    assert_equal "medium", stored.first.value_text
    assert_equal roast.id, stored.first.custom_field_id
    refute_equal hidden.id, stored.first.custom_field_id

    Current.organization_id = @org.id
    closed = posting_for(@job, status: "draft", title: "Closed")
    post "/v1/public/careers/#{@org.slug}/apply/#{closed.id}",
         params: { answers: { display_name: "Pat Example", email: "pat@example.com", roast: "medium" } },
         as: :json
    assert_response :unprocessable_entity
    assert_match(/posting_closed/, response.parsed_body["title"])
  end
end
