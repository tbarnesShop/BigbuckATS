# frozen_string_literal: true

require "test_helper"
require_relative "mail_transport_contract"

class MailTransportSandboxTest < ActiveSupport::TestCase
  include MailTransportContract

  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "SbxCo", slug: "sbx-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@sbx.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@sbx.test", provider: "sandbox",
      status: "connected", secret_ref: "sandbox://mailbox")
  end

  teardown { Current.reset }

  def transport_mailbox = @mailbox
  def recipient = "prospect@example.com"

  test "sandbox stores a real RFC 822 message with threading and extra headers" do
    first = deliver
    result = deliver(thread_id: first[:thread_id], in_reply_to: first[:rfc822_message_id],
      headers: { "List-Unsubscribe" => "<https://example.test/u/abc>" })
    mime = Mail.read_from_string(SandboxMessage.find_by!(rfc822_message_id: result[:rfc822_message_id]).mime)

    assert_equal result[:rfc822_message_id], mime.message_id
    assert_equal first[:rfc822_message_id], mime.in_reply_to
    assert_equal first[:rfc822_message_id], Array(mime.references).first
    assert_equal "<https://example.test/u/abc>", mime["List-Unsubscribe"].to_s
    assert_equal [ "rec@sbx.test" ], mime.from
    assert_equal [ "prospect@example.com" ], mime.to
  end

  test "sandbox messages stay inside their organization" do
    deliver
    other = OrganizationProvisioner.call(
      name: "Other", slug: "oth-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@oth.test", owner_name: "O"
    )
    Current.organization_id = other[:organization].id
    assert_equal 0, SandboxMessage.count
  end

  test "an unknown provider is rejected" do
    @mailbox.provider = "carrier-pigeon"
    assert_raises(ArgumentError) { MailTransport.for(@mailbox) }
    refute @mailbox.valid?
  end
end

class MailTransportGmailFakeTest < ActiveSupport::TestCase
  include MailTransportContract

  setup do
    GmailClient.backend = GmailClient::Fake.new
    @provisioned = OrganizationProvisioner.call(
      name: "GmCo", slug: "gm-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@gm.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@gm.test", status: "connected", secret_ref: "sm://x")
  end

  teardown do
    GmailClient.backend = nil
    Current.reset
  end

  def transport_mailbox = @mailbox
  def recipient = "prospect@example.com"
end
