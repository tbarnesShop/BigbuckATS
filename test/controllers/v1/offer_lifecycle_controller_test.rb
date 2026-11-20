# frozen_string_literal: true

require "test_helper"

class V1::OfferLifecycleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "LifeCo", slug: "life-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@life.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    ApprovalPolicy.create!(
      key: "default-offers", name: "Default", applies_to: "offer",
      priority: 0, is_catch_all: true
    )
    @template = OfferTemplate.create!(
      key: "us-ft", name: "US FT",
      body: "Dear {{ candidate.display_name }}, offer for {{ job.title }}.",
      expires_after_days: 7
    )
    pipe_template = PipelineTemplate.create!(key: "default", name: "Default", object_type: "job")
    pipe_template.publish!(stages: [ { "key" => "offer", "name" => "Offer", "type" => "offer" } ])
    pipeline = Pipeline.build_from_template!(template: pipe_template)
    @job = Job.create!(title: "Eng", status: "active", pipeline: pipeline)
    @person = Person.create!(display_name: "Alex", primary_email: "alex@life.test")
    @application = ApplicationCreator.call(job: @job, person: @person)
  end

  teardown { Current.reset }

  def headers(extra = {})
    {
      "X-Organization-Id" => @org.id,
      "X-Actor-Id" => @user.id,
      "Idempotency-Key" => "k-#{SecureRandom.hex(4)}"
    }.merge(extra)
  end

  test "create submit approve send decline via REST" do
    post "/v1/applications/#{@application.id}/offers",
         params: { offer: { fields: { "base-salary" => 120_000 } } },
         headers: headers, as: :json
    assert_response :created
    offer_id = response.parsed_body["id"]
    assert_equal "draft", response.parsed_body["status"]

    post "/v1/offers/#{offer_id}/submit", headers: headers, as: :json
    assert_response :success
    # catch-all with no steps may auto-approve
    status = response.parsed_body["status"]
    assert_includes %w[pending_approval approved], status

    if status == "pending_approval"
      post "/v1/offers/#{offer_id}/approve",
           params: { override: true },
           headers: headers, as: :json
      assert_response :success
      assert_equal "approved", response.parsed_body["status"]
    end

    post "/v1/offers/#{offer_id}/send",
         params: { template_key: "us-ft", to_email: "alex@life.test" },
         headers: headers, as: :json
    assert_response :success
    assert_equal "sent", response.parsed_body["status"]
    token = response.parsed_body.dig("send", "token")
    assert token.present?

    post "/v1/public/offers/#{token}/decline",
         params: { reason_key: "not_interested" },
         as: :json
    assert_response :success
    assert_equal "declined", response.parsed_body["status"]
  end

  test "a recruiter records an acceptance, then marks the candidate hired" do
    post "/v1/applications/#{@application.id}/offers",
         params: { offer: { fields: { "base-salary" => 130_000 } } }, headers: headers, as: :json
    offer_id = response.parsed_body["id"]
    post "/v1/offers/#{offer_id}/submit", headers: headers, as: :json
    if response.parsed_body["status"] == "pending_approval"
      post "/v1/offers/#{offer_id}/approve", params: { override: true }, headers: headers, as: :json
    end
    post "/v1/offers/#{offer_id}/send", params: { template_key: "us-ft", to_email: "alex@life.test" }, headers: headers, as: :json
    assert_equal "sent", response.parsed_body["status"]

    post "/v1/offers/#{offer_id}/record_response", params: { response: "accepted", note: "Accepted by phone" },
         headers: headers, as: :json
    assert_response :created
    assert_equal "accepted", response.parsed_body["status"]
    row = OfferResponse.order(:created_at).last
    assert_equal [ "recorded_by_user", @user.id ], [ row.responded_by, row.recorded_by_user_id ]

    post "/v1/offers/#{offer_id}/record_response", params: { response: "accepted" }, headers: headers, as: :json
    assert_response :unprocessable_entity, "an offer that is no longer sent cannot take another response"

    post "/v1/applications/#{@application.id}/transitions", params: { command: "hire" }, headers: headers, as: :json
    assert_response :created
    assert_equal "hired", response.parsed_body["status"]
  end

  test "hiring moves the candidate into the Hired stage" do
    Organization.find(@org.id).merge_settings!("hire_requires_accepted_offer" => false)
    post "/v1/applications/#{@application.id}/transitions", params: { command: "hire" }, headers: headers, as: :json
    assert_response :created
    assert_equal [ "hired", "hired" ], [ @application.reload.status, @application.current_stage_key ]
    assert_equal "Hired", @application.pipeline.stage("hired")["name"]
    post "/v1/applications/#{ApplicationCreator.call(job: @job, person: Person.create!(display_name: "B", primary_email: "b@life.test")).id}/transitions",
         params: { command: "move", to_stage_key: "hired" }, headers: headers, as: :json
    assert_response :unprocessable_entity, "a plain move cannot skip the hire checks"
  end

  test "offer checklist tracks references and the verbal offer" do
    post "/v1/applications/#{@application.id}/offers", params: { offer: { fields: { "base-salary" => 1 } } }, headers: headers, as: :json
    offer_id = response.parsed_body["id"]
    patch "/v1/offers/#{offer_id}/checklist", params: { item: "references", state: "complete", note: "Two strong references" }, headers: headers, as: :json
    assert_response :success
    assert_equal "complete", response.parsed_body.dig("checklist", "references", "state")
    patch "/v1/offers/#{offer_id}/checklist", params: { item: "verbal", state: "made" }, headers: headers, as: :json
    assert_equal %w[complete made], %w[references verbal].map { |k| response.parsed_body.dig("checklist", k, "state") }
    patch "/v1/offers/#{offer_id}/checklist", params: { item: "verbal", state: "shouted" }, headers: headers, as: :json
    assert_response :unprocessable_entity
  end

  test "only an owner can override someone else's approval; the scoped approver can still see it" do
    hm = User.create!(email: "hm-#{SecureRandom.hex(3)}@life.test", name: "Harper")
    hm_membership = Membership.create!(user: hm, role: Role.find_by!(key: "hiring_manager"), status: "active")
    # Harper only sees Design people; the candidate is untagged, so only the approval lets her read the offer.
    department = Dimension.find_by!(key: "department")
    MembershipScope.create!(membership: hm_membership, dimension: department,
      dimension_value: DimensionValue.create!(dimension: department, key: "design-#{SecureRandom.hex(2)}", label: "Design"),
      include_descendants: true)
    recruiter = User.create!(email: "rec-#{SecureRandom.hex(3)}@life.test", name: "Riley")
    Membership.create!(user: recruiter, role: Role.find_by!(key: "recruiter"), status: "active")
    HiringTeam.create!(job: @job).members.create!(user: hm, team_role: "hiring-manager")
    policy = ApprovalPolicy.create!(key: "hm-#{SecureRandom.hex(2)}", name: "HM", applies_to: "offer", priority: 50, is_catch_all: false, conditions: {})
    ApprovalPolicyStep.create!(approval_policy: policy, position: 1, name: "HM", mode: "sequential",
      approvers: [ "role:hiring-manager" ], require_mode: "all", if_no_approver: "skip")
    post "/v1/applications/#{@application.id}/offers", params: { offer: { fields: { "base-salary" => 1 } } }, headers: headers("X-Actor-Id" => recruiter.id), as: :json
    offer_id = response.parsed_body["id"]
    post "/v1/offers/#{offer_id}/submit", headers: headers("X-Actor-Id" => recruiter.id), as: :json
    assert_equal "pending_approval", response.parsed_body["status"]
    refute response.parsed_body["can_override"]

    post "/v1/offers/#{offer_id}/approve", params: { override: true }, headers: headers("X-Actor-Id" => recruiter.id), as: :json
    assert_response :forbidden
    assert_equal "override_requires_owner", response.parsed_body["code"]

    get "/v1/offers/#{offer_id}", headers: headers("X-Actor-Id" => hm.id)
    assert_response :success, "the assigned approver can read the offer they must approve"
    get "/v1/offers", headers: headers("X-Actor-Id" => hm.id)
    get "/v1/offers/#{offer_id}", headers: headers
    assert response.parsed_body["can_override"], "the owner sees the override"
    post "/v1/offers/#{offer_id}/approve", params: { override: true }, headers: headers, as: :json
    assert_response :success
    assert_equal "approved", response.parsed_body["status"]
    approval = response.parsed_body["approvals"].last
    assert_equal [ true, "Owner", "Harper" ], approval.values_at("is_override", "approved_by_name", "approver_name")
  end

  test "a recruiter sees the compensation on the offers they work on" do
    recruiter = User.create!(email: "comp-#{SecureRandom.hex(3)}@life.test", name: "Riley")
    Membership.create!(user: recruiter, role: Role.find_by!(key: "recruiter"), status: "active")
    post "/v1/applications/#{@application.id}/offers", params: { offer: { fields: { "base_salary" => 150_000 } } }, headers: headers, as: :json
    offer_id = response.parsed_body["id"]
    issued = CredentialIssuer.call(kind: "session", name: "recruiter", user: recruiter, expires_at: 1.hour.from_now)
    Current.reset
    get "/v1/offers/#{offer_id}", headers: { "Authorization" => "Bearer #{issued.token}" }
    assert_response :success
    assert_equal 150_000, response.parsed_body.dig("fields", "base_salary")
    refute response.parsed_body["terms_hidden"]
  end
end
