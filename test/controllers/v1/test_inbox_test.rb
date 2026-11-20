# frozen_string_literal: true

require "test_helper"

class V1::TestInboxTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "InboxCo", slug: "i-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@i.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    Current.organization_id = @org.id
    Current.actor_id = @provisioned[:user].id
    @headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @provisioned[:user].id }
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@i.test", provider: "sandbox", status: "connected",
      secret_ref: "sandbox://mailbox", user: @provisioned[:user])
    @person = PersonMatcher.find_or_create(display_name: "Ivy", email: "ivy@example.com",
      viewer: @provisioned[:membership]).person
    @sequence = Sequence.find_by!(key: "starter-outreach")
    @enrollment = SequenceRunner.enroll!(sequence: @sequence, person: @person, mailbox: @mailbox)
  end

  teardown { Current.reset }

  def sent_message = SandboxMessage.find_by!(mailbox_id: @mailbox.id, direction: "outbound")

  test "the inbox lists what was sent, marking unanswered mail" do
    get "/v1/mailboxes/#{@mailbox.id}/messages", headers: @headers
    assert_response :success
    row = response.parsed_body["data"].first
    assert_equal "outbound", row["direction"]
    assert_equal false, row["answered"]
  end

  test "a simulated reply threads onto the person and stops the sequence" do
    post "/v1/mailboxes/#{@mailbox.id}/simulate", params: { message_id: sent_message.id, kind: "reply" },
         headers: @headers, as: :json
    assert_response :created
    assert_equal "reply", @enrollment.reload.stop_reason
    assert Communication.exists?(person_id: @person.id, direction: "inbound")

    get "/v1/mailboxes/#{@mailbox.id}/messages", headers: @headers
    assert_equal [ true ], response.parsed_body["data"].select { |r| r["direction"] == "outbound" }.map { |r| r["answered"] }
  end

  test "a simulated bounce stops with reason bounce and an out-of-office does not stop" do
    post "/v1/mailboxes/#{@mailbox.id}/simulate", params: { message_id: sent_message.id, kind: "auto_reply" },
         headers: @headers, as: :json
    assert_response :created
    assert_equal "active", @enrollment.reload.status
    assert_equal "out_of_office", Communication.where(person_id: @person.id, direction: "inbound").last.classification

    post "/v1/mailboxes/#{@mailbox.id}/simulate", params: { message_id: sent_message.id, kind: "bounce" },
         headers: @headers, as: :json
    assert_equal "bounce", @enrollment.reload.stop_reason
  end

  test "only Test mailboxes can be simulated" do
    gmail = Mailbox.create!(kind: "shared", email: "g@i.test", provider: "gmail", status: "connected", secret_ref: "sm://g")
    get "/v1/mailboxes/#{gmail.id}/messages", headers: @headers
    assert_response :unprocessable_content
  end

  test "bulk task answers every unanswered message" do
    answered = SandboxInbox.answer_unanswered!(mailbox: @mailbox, kind: "reply", limit: 5)
    assert_equal 1, answered.size
    assert_empty SandboxInbox.answer_unanswered!(mailbox: @mailbox, kind: "reply", limit: 5)
  end
end
