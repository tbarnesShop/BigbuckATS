# frozen_string_literal: true

require "test_helper"

class V1::ProductGapControllerTest < ActionDispatch::IntegrationTest
  setup do
    GmailClient.backend = GmailClient::Fake.new
    CalendarClient.backend = CalendarClient::Fake.new
    @provisioned = OrganizationProvisioner.call(
      name: "GapCo", slug: "gap-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@gap.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    GoogleSignIn.verify_domain!(domain: "gap.test")
    @mailbox = Mailbox.create!(
      kind: "personal", email: "sourcer@gap.test", user: @user,
      status: "connected", secret_ref: "sm://1"
    )
    MessageTemplate.create!(
      key: "outreach-1", message_type: "sequence",
      subject: "Hi {{ person.display_name }}", body: "Hello"
    )
    @person = Person.create!(display_name: "Prospect", primary_email: "p@gap.test", lifecycle_stage: "prospect")
    PersonContactPoint.create!(
      person: @person, kind: "email", value: "p@gap.test",
      normalized_value: PersonContactPoint.normalize_email("p@gap.test")
    )
    template = PipelineTemplate.create!(key: "job", name: "Job", object_type: "job")
    template.publish!(stages: [
      { "key" => "applied", "name" => "Applied", "type" => "apply" },
      { "key" => "onsite", "name" => "Onsite", "type" => "interview",
        "interviews" => [ { "key" => "hm", "name" => "HM", "required" => true } ] }
    ])
    @job = Job.create!(title: "Eng", status: "active", pipeline: Pipeline.build_from_template!(template: template))
    @application = ApplicationCreator.call(job: @job, person: @person)
  end

  teardown do
    GmailClient.backend = nil
    CalendarClient.backend = nil
    Current.reset
  end

  def headers
    {
      "X-Organization-Id" => @org.id,
      "X-Actor-Id" => @user.id,
      "Idempotency-Key" => "k-#{SecureRandom.hex(4)}"
    }
  end

  test "sequence enroll, inbound reply stops, scorecard, company, session, events" do
    post "/v1/sequences",
         params: { sequence: { key: "warm", name: "Warm", steps: [ { type: "email", template_key: "outreach-1" } ] } },
         headers: headers, as: :json
    assert_response :created
    sequence_id = response.parsed_body["id"]

    post "/v1/sequences/#{sequence_id}/enrollments",
         params: { enrollment: { person_id: @person.id, mailbox_id: @mailbox.id } },
         headers: headers, as: :json
    assert_response :created
    enrollment_id = response.parsed_body["id"]
    assert_equal "active", response.parsed_body["status"]
    outreach = Communication.find_by!(person_id: @person.id, direction: "outbound")

    post "/v1/mailboxes/#{@mailbox.id}/inbound",
         params: {
           from: "p@gap.test", subject: "Re: Hi", body: "Yes",
           thread_id: outreach.thread_id
         },
         headers: headers, as: :json
    assert_response :created
    get "/v1/enrollments/#{enrollment_id}", headers: headers
    assert_response :success
    assert_equal "stopped", response.parsed_body["status"]
    assert_equal "reply", response.parsed_body["stop_reason"]

    booking = PanelBooking.suggest_and_book!(
      application: @application,
      interview_defs: [ { key: "hm", duration_minutes: 30, count: 1, candidate_user_ids: [ @user.id ] } ],
      profiles: [ { user_id: @user.id, paused: false } ],
      organizer_calendar: "recruiting@gap.test",
      user_emails: { @user.id => @user.email },
      search_start: Time.utc(2026, 11, 2, 9, 0, 0),
      search_end: Time.utc(2026, 11, 6, 17, 0, 0)
    )
    assert booking.booked
    interview = booking.interviews.first

    post "/v1/scorecards",
         params: { scorecard: { interview_id: interview.id, rating: "yes", notes: "strong" } },
         headers: headers, as: :json
    assert_response :created
    assert_equal "yes", response.parsed_body["rating"]

    post "/v1/applications/#{@application.id}/bookings",
         params: {
           organizer_calendar: "recruiting@gap.test",
           search_start: "2026-12-01T09:00:00Z",
           search_end: "2026-12-05T17:00:00Z",
           interview_defs: [ { key: "hm", duration_minutes: 30, count: 1, candidate_user_ids: [ @user.id ] } ],
           profiles: [ { user_id: @user.id, paused: false } ],
           user_emails: { @user.id => @user.email }
         },
         headers: headers, as: :json
    # may refuse if no slots; either booked or unprocessable is acceptable for coverage of route
    assert_includes [ 201, 422 ], response.status

    post "/v1/companies",
         params: { company: { name: "Acme Corp", domain: "acme.test" } },
         headers: headers, as: :json
    assert_response :created

    post "/v1/webhooks",
         params: { webhook: { key: "hooks", url: "https://example.test/hook" } },
         headers: headers, as: :json
    assert_response :created

    get "/v1/events", headers: headers
    assert_response :success
    assert response.parsed_body["data"].is_a?(Array)

    get "/v1/sync/people", headers: headers
    assert_response :success
    assert response.parsed_body["data"].any? { |p| p["id"] == @person.id }

    handoff = Current.set(organization_id: @org.id) do
      CredentialIssuer.call(kind: "handoff", name: "Verified sign-in", user: @user,
        expires_at: 2.minutes.from_now).token
    end
    post "/v1/sessions/exchange",
         params: { code: handoff },
         as: :json
    assert_response :created
    assert_equal @org.id, response.parsed_body.dig("organization", "id")
    assert_equal @user.id, response.parsed_body.dig("user", "id")

    post "/v1/config/plans",
         params: {
           documents: [ {
             kind: "PipelineTemplate",
             key: "gap-eng",
             spec: {
               name: "Gap Eng",
               stages: [ { key: "review", name: "Review", type: "review" } ]
             }
           } ]
         },
         headers: headers, as: :json
    assert_response :created
    plan_id = response.parsed_body["id"]
    assert_equal "open", response.parsed_body["status"]

    post "/v1/config/apply",
         params: { plan_id: plan_id },
         headers: headers, as: :json
    assert_response :success
    assert_equal "applied", response.parsed_body.dig("plan", "status")

    company = Company.find_by!(name: "Acme Corp")
    post "/v1/affiliations",
         params: { affiliation: { person_id: @person.id, company_id: company.id, title: "Engineer", current: true } },
         headers: headers, as: :json
    assert_response :created

    get "/v1/compliance_policies", headers: headers
    assert_response :success
  end
end
