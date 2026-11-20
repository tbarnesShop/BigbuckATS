# frozen_string_literal: true

require "test_helper"

class V1::SandboxMailboxTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "SbxApi", slug: "sa-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@sa.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    @headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
  end

  teardown { Current.reset }

  def idem = { "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }

  test "a Test mailbox connects in one call with no domain check and no grant" do
    post "/v1/mailboxes", params: { mailbox: { email: "me@unverified-domain.test", provider: "sandbox" } },
         headers: @headers.merge(idem), as: :json
    assert_response :created
    body = response.parsed_body
    assert_equal "sandbox", body["provider"]
    assert_equal "connected", body["status"]
    refute body.key?("secret_ref")
  end

  test "an unknown provider is rejected" do
    post "/v1/mailboxes", params: { mailbox: { email: "me@x.test", provider: "pigeon" } },
         headers: @headers.merge(idem), as: :json
    assert_response :unprocessable_content
  end

  test "an inbound reply from a new address threads onto the person through the REST hook" do
    mailbox = Mailbox.create!(kind: "personal", email: "rec@sa.test", provider: "sandbox",
      status: "connected", secret_ref: "sandbox://mailbox")
    person = PersonMatcher.find_or_create(display_name: "Pat", email: "pat@example.com",
      viewer: @provisioned[:membership]).person
    sent = MessageSender.send_now!(mailbox: mailbox, person: person, subject: "Hi", body: "Chat?")

    post "/v1/mailboxes/#{mailbox.id}/inbound",
         params: { from: "pat-personal@example.org", subject: "Re: Hi", body: "Yes", in_reply_to: sent.rfc822_message_id },
         headers: @headers.merge(idem), as: :json
    assert_response :created
    assert_equal person.id, response.parsed_body["person_id"]
    assert_equal sent.thread_id, response.parsed_body["thread_id"]
  end
end
