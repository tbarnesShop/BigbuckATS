# frozen_string_literal: true

require "test_helper"

class V1::SequencesV2Test < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "SeqV2", slug: "sq-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@sq.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@sq.test", provider: "sandbox",
      status: "connected", secret_ref: "sandbox://mailbox", user: @user)
    @person = PersonMatcher.find_or_create(display_name: "Pat Prospect", email: "pat@sq.test", viewer: @provisioned[:membership]).person
  end

  teardown { Current.reset }

  def headers
    { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id, "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }
  end

  def steps
    [
      { type: "email", template_key: "starter-intro" },
      { type: "wait", days: 2 },
      { type: "task", title: "Call", task_type: "call" },
      { type: "email", template_key: "starter-follow-up" }
    ]
  end

  def create_sequence(extra = {})
    post "/v1/sequences", params: { sequence: { key: "s-#{SecureRandom.hex(3)}", name: "V2", steps: steps }.merge(extra) }, headers: headers, as: :json
    response.parsed_body
  end

  test "create normalizes steps: stable ids, channel, owner, description" do
    seq = create_sequence(description: "Cold outreach")
    assert_response :created
    assert_equal @user.id, seq["owner_user_id"]
    assert_equal "Cold outreach", seq["description"]
    ids = seq["steps"].map { |s| s["id"] }
    assert_equal 4, ids.uniq.size
    assert_equal "email", seq["steps"][0]["channel"]
    assert_equal true, seq["steps"][2]["pause_until_done"]
  end

  test "invalid steps are rejected with a step-specific error" do
    post "/v1/sequences", params: { sequence: { key: "bad", name: "Bad", steps: [ { type: "email", template_key: "nope" } ] } }, headers: headers, as: :json
    assert_response :unprocessable_entity
    assert_match(/step_1_template_not_found/, response.body)
    post "/v1/sequences", params: { sequence: { key: "bad2", name: "Bad", steps: [ { type: "fax" } ] } }, headers: headers, as: :json
    assert_match(/step_1_type_invalid/, response.body)
    post "/v1/sequences", params: { sequence: { key: "bad3", name: "Bad", steps: [ { type: "wait", days: 0 } ] } }, headers: headers, as: :json
    assert_match(/step_1_wait_invalid/, response.body)
  end

  test "update keeps step ids that the client sends back" do
    seq = create_sequence
    edited = seq["steps"].reverse
    patch "/v1/sequences/#{seq['id']}", params: { sequence: { name: "Renamed", steps: edited } }, headers: headers, as: :json
    assert_response :success
    assert_equal "Renamed", response.parsed_body["name"]
    assert_equal edited.map { |s| s["id"] }, response.parsed_body["steps"].map { |s| s["id"] }
  end

  test "preview renders each email step for the person" do
    seq = create_sequence
    get "/v1/sequences/#{seq['id']}/preview", params: { person_id: @person.id }, headers: headers
    assert_response :success
    emails = response.parsed_body["steps"].select { |s| s["type"] == "email" }
    assert_equal 2, emails.size
    assert emails.all? { |e| e["subject"].present? && e["body"].present? }
    refute_match(/\{\{/, emails.first["body"])
  end

  test "stats count messages per step" do
    seq = create_sequence
    sequence = Sequence.find(seq["id"])
    enrollment = SequenceRunner.enroll!(sequence: sequence, person: @person, mailbox: @mailbox)
    first_id = sequence.steps.first["id"]
    assert_equal first_id, ScheduledMessage.where(sequence_enrollment_id: enrollment.id).first.sequence_step_id
    get "/v1/sequences/#{seq['id']}/stats", headers: headers
    assert_response :success
    body = response.parsed_body
    assert_equal 1, body["enrolled"]
    first = body["steps"].first
    assert_equal 1, first["messages"].values.sum
    assert_equal 0, body["steps"].last["messages"].values.sum
  end
end
