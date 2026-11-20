# frozen_string_literal: true

require "test_helper"

class V1::SourcingOpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    GmailClient.backend = GmailClient::Fake.new
    @provisioned = OrganizationProvisioner.call(
      name: "SourceCo", slug: "src-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@src.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    @org.merge_settings!("contact_cooldown_days" => 0)
    @mailbox = Mailbox.create!(
      kind: "personal", email: "sourcer@src.test", user: @user,
      status: "connected", secret_ref: "sm://1"
    )
    MessageTemplate.create!(
      key: "outreach-1", message_type: "sequence",
      subject: "Hi {{ person.display_name }}", body: "Hello"
    )
    @person = Person.create!(display_name: "Ada Lovelace", primary_email: "ada@src.test", lifecycle_stage: "prospect")
    PersonContactPoint.create!(
      person: @person, kind: "email", value: "ada@src.test",
      normalized_value: PersonContactPoint.normalize_email("ada@src.test")
    )
    @other = Person.create!(display_name: "Grace Hopper", primary_email: "grace@src.test", lifecycle_stage: "candidate")
    template = PipelineTemplate.create!(key: "job", name: "Job", object_type: "job")
    template.publish!(stages: [
      { "key" => "applied", "name" => "Applied", "type" => "apply" },
      { "key" => "onsite", "name" => "Onsite", "type" => "interview" }
    ])
    @pipeline = Pipeline.build_from_template!(template: template)
    @job = Job.create!(title: "Staff Engineer", status: "active", pipeline: @pipeline)
  end

  teardown do
    GmailClient.backend = nil
    Current.reset
  end

  def headers
    {
      "X-Organization-Id" => @org.id,
      "X-Actor-Id" => @user.id,
      "Idempotency-Key" => "k-#{SecureRandom.hex(4)}"
    }
  end

  test "people search filters by q and lifecycle" do
    get "/v1/people", params: { q: "Ada" }, headers: headers
    assert_response :success
    names = response.parsed_body["data"].map { |p| p["display_name"] }
    assert_includes names, "Ada Lovelace"
    assert_not_includes names, "Grace Hopper"

    get "/v1/people", params: { lifecycle_stage: "candidate" }, headers: headers
    assert_response :success
    assert_equal [ "Grace Hopper" ], response.parsed_body["data"].map { |p| p["display_name"] }
  end

  test "saved search create list and destroy" do
    post "/v1/saved_searches",
         params: { saved_search: { name: "Prospects", filters: { lifecycle_stage: "prospect" } } },
         headers: headers, as: :json
    assert_response :created
    id = response.parsed_body["id"]

    get "/v1/saved_searches", headers: headers
    assert_response :success
    assert_equal 1, response.parsed_body["data"].size

    delete "/v1/saved_searches/#{id}", headers: headers
    assert_response :no_content
  end

  test "bulk enroll sequence and set dnc" do
    post "/v1/sequences",
         params: { sequence: { key: "warm", name: "Warm", shared: true, is_template: true,
                               steps: [ { type: "email", template_key: "outreach-1" }, { type: "task", title: "Call" } ] } },
         headers: headers, as: :json
    assert_response :created
    sequence_id = response.parsed_body["id"]
    assert_equal true, response.parsed_body["shared"]
    assert_equal true, response.parsed_body["is_template"]

    post "/v1/people/bulk",
         params: {
           bulk_action: "enroll_sequence",
           person_ids: [ @person.id ],
           sequence_id: sequence_id,
           mailbox_id: @mailbox.id
         },
         headers: headers, as: :json
    assert_response :success
    assert response.parsed_body["results"].first["ok"]
    assert_equal 1, SourcingTask.where(person_id: @person.id).count

    post "/v1/sequences/#{sequence_id}/bulk_enroll",
         params: { person_ids: [ @other.id ], mailbox_id: @mailbox.id },
         headers: headers, as: :json
    assert_response :success
    assert response.parsed_body["results"].first["ok"]

    post "/v1/people/bulk",
         params: { bulk_action: "set_dnc", person_ids: [ @other.id ], reason: "opt_out" },
         headers: headers, as: :json
    assert_response :success
    assert @other.reload.do_not_contact
    assert_equal "opt_out", @other.do_not_contact_reason
  end

  test "rediscovery surfaces past rejected applicants" do
    app = ApplicationCreator.call(job: @job, person: @person)
    app.update!(status: "rejected")

    get "/v1/jobs/#{@job.id}/rediscovery", headers: headers
    assert_response :success
    row = response.parsed_body["data"].find { |r| r["person"]["id"] == @person.id }
    assert row
    assert_includes row["reasons"], "prior_application_same_job"
    assert_operator row["score"], :>, 0
  end

  test "analytics funnel and sourcing" do
    ApplicationCreator.call(job: @job, person: @person)
    get "/v1/analytics/funnel", params: { job_id: @job.id }, headers: headers
    assert_response :success
    assert_equal 1, response.parsed_body["total_applications"]

    get "/v1/analytics/sourcing", headers: headers
    assert_response :success
    assert response.parsed_body.key?("enrollments_by_status")
  end

  test "dnc company blocks enrollment" do
    company = Company.create!(name: "Blocked Co", domain: "blocked.test")
    PersonAffiliation.create!(person: @person, company: company, current: true, title: "Eng")
    post "/v1/dnc_companies",
         params: { dnc_company: { company_id: company.id, reason: "competitor" } },
         headers: headers, as: :json
    assert_response :created

    post "/v1/sequences",
         params: { sequence: { key: "x", name: "X", steps: [ { type: "email", template_key: "outreach-1" } ] } },
         headers: headers, as: :json
    sequence_id = response.parsed_body["id"]

    post "/v1/sequences/#{sequence_id}/enrollments",
         params: { enrollment: { person_id: @person.id, mailbox_id: @mailbox.id } },
         headers: headers, as: :json
    assert_response :unprocessable_entity
    assert_match(/company_dnc/, response.parsed_body["title"])
  end

  test "contact cooldown blocks re-outreach" do
    @org.merge_settings!("contact_cooldown_days" => 14)
    Communication.create!(
      person: @person, direction: "outbound", channel: "email", status: "sent",
      subject: "hi", body: "hi", message_type: "outreach"
    )
    post "/v1/sequences",
         params: { sequence: { key: "y", name: "Y", steps: [ { type: "email", template_key: "outreach-1" } ] } },
         headers: headers, as: :json
    sequence_id = response.parsed_body["id"]
    post "/v1/sequences/#{sequence_id}/enrollments",
         params: { enrollment: { person_id: @person.id, mailbox_id: @mailbox.id } },
         headers: headers, as: :json
    assert_response :unprocessable_entity
    assert_match(/cooldown/, response.parsed_body["title"])
  end

  test "referral creates person and optional application" do
    post "/v1/referrals",
         params: { referral: { display_name: "Ref Person", email: "ref@src.test", job_id: @job.id, note: "great" } },
         headers: headers, as: :json
    assert_response :created
    body = response.parsed_body
    assert_equal "converted", body["status"]
    assert body["application_id"].present?
    assert_equal @user.id, body["referrer_user_id"]
  end

  test "requisition headcount open close and job link" do
    post "/v1/requisitions",
         params: { requisition: { code: "ENG-1", title: "Staff Eng", headcount: 2 } },
         headers: headers, as: :json
    assert_response :created
    req_id = response.parsed_body["id"]
    assert_equal 2, response.parsed_body["headcount"]
    assert_equal 2, response.parsed_body["openings_remaining"]

    post "/v1/requisitions/#{req_id}/open", headers: headers, as: :json
    assert_response :success
    assert_equal "open", response.parsed_body["status"]

    post "/v1/jobs",
         params: { job: { title: "Staff Eng seat", requisition_id: req_id } },
         headers: headers, as: :json
    assert_response :created
    assert_equal req_id, response.parsed_body["requisition_id"]

    get "/v1/requisitions/#{req_id}", headers: headers
    assert_response :success
    assert_equal 1, response.parsed_body["jobs"].size

    post "/v1/requisitions/#{req_id}/close", headers: headers, as: :json
    assert_response :success
    assert_equal "closed", response.parsed_body["status"]
  end
end
