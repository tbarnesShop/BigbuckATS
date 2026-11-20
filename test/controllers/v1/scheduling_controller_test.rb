# frozen_string_literal: true

require "test_helper"

class V1::SchedulingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @fake = CalendarClient::Fake.new
    CalendarClient.backend = @fake
    @provisioned = OrganizationProvisioner.call(
      name: "SchedCo", slug: "sch-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@sch.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    @interviewer = User.create!(email: "int-#{SecureRandom.hex(2)}@sch.test", name: "Int")
    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [
      { "key" => "onsite", "name" => "Onsite", "type" => "interview",
        "interviews" => [ { "key" => "screen", "name" => "Screen" } ] }
    ])
    pipeline = Pipeline.build_from_template!(template: template)
    job = Job.create!(title: "Eng", status: "active", pipeline: pipeline)
    person = Person.create!(display_name: "Cand", primary_email: "cand@sch.test")
    @application = ApplicationCreator.call(job: job, person: person)
    @start = Time.utc(2026, 11, 2, 9, 0, 0)
    @finish = @start + 5.days
  end

  teardown do
    CalendarClient.backend = nil
    Current.reset
  end

  test "create link, public show, and book" do
    post "/v1/applications/#{@application.id}/scheduling_links",
         params: { interview_keys: [ "screen" ] },
         headers: {
           "X-Organization-Id" => @org.id,
           "X-Actor-Id" => @user.id,
           "Idempotency-Key" => "l-#{SecureRandom.hex(4)}"
         },
         as: :json
    assert_response :created
    token = response.parsed_body["token"]
    assert token.present?

    get "/v1/public/scheduling/#{token}"
    assert_response :success
    assert response.parsed_body["usable"]
    assert_equal "Eng", response.parsed_body.dig("application", "job_title")

    post "/v1/public/scheduling/#{token}/book",
         params: {
           interview_defs: [
             { key: "screen", duration_minutes: 30, count: 1, candidate_user_ids: [ @interviewer.id ] }
           ],
           profiles: [ { user_id: @interviewer.id, paused: false } ],
           organizer_calendar: "org@sch.test",
           user_emails: { @interviewer.id => @interviewer.email },
           search_start: @start.iso8601,
           search_end: @finish.iso8601
         },
         as: :json
    assert_response :success
    assert response.parsed_body["booked"]
    assert_equal 1, response.parsed_body["interviews"].size

    get "/v1/applications/#{@application.id}/interviews",
        headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :success
    assert_equal 1, response.parsed_body["data"].size
  end

  test "recruiter previews without writes then confirms only the reviewed option" do
    travel_to(@start - 1.day)
    headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    input = {
      interview_defs: [ { key: "screen", duration_minutes: 30, count: 1, candidate_user_ids: [ @interviewer.id ] } ],
      profiles: [ { user_id: @interviewer.id, paused: false } ],
      organizer_calendar: "org@sch.test", user_emails: { @interviewer.id => @interviewer.email },
      search_start: @start.iso8601, search_end: @finish.iso8601
    }
    assert_no_difference "Interview.count" do
      post "/v1/applications/#{@application.id}/booking_options", params: input, headers: headers, as: :json
    end
    assert_response :success
    selected = response.parsed_body.fetch("options")[1]
    assert_empty @fake.events
    assert_difference "Interview.count", 1 do
      post "/v1/applications/#{@application.id}/bookings", params: { booking_token: selected.fetch("token") },
           headers: headers.merge("Idempotency-Key" => "preview-#{SecureRandom.hex(4)}"), as: :json
    end
    assert_response :created
    assert_equal Time.iso8601(selected["starts_at"]), Time.iso8601(response.parsed_body.dig("interviews", 0, "starts_at"))
  end
end
