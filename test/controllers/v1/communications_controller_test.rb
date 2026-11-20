# frozen_string_literal: true

require "test_helper"

class V1::CommunicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @fake = GmailClient::Fake.new
    GmailClient.backend = @fake
    @provisioned = OrganizationProvisioner.call(
      name: "CommCo", slug: "comm-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@comm.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    @mailbox = Mailbox.create!(
      kind: "shared", email: "recruiting@comm.test",
      status: "connected", secret_ref: "sm://shared"
    )
    @person = Person.create!(display_name: "Pat", primary_email: "pat@example.com")
  end

  teardown do
    GmailClient.backend = nil
    Current.reset
  end

  test "send communication and list timeline" do
    post "/v1/people/#{@person.id}/communications",
         params: {
           mailbox_id: @mailbox.id,
           subject: "Hello",
           body: "Want to chat?",
           message_type: "outreach"
         },
         headers: {
           "X-Organization-Id" => @org.id,
           "X-Actor-Id" => @user.id,
           "Idempotency-Key" => "c-#{SecureRandom.hex(4)}"
         },
         as: :json
    assert_response :created
    assert_equal "sent", response.parsed_body["status"]
    assert_equal 1, @fake.sent.size

    get "/v1/people/#{@person.id}/timeline",
        headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :success
    assert response.parsed_body["data"].any? { |e| e["event_type"] == "communication.sent" }
  end
end
