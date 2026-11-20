# frozen_string_literal: true

require "test_helper"

class SandboxErasureTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "SbxEr", slug: "se-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@se.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@se.test", provider: "sandbox",
      status: "connected", secret_ref: "sandbox://mailbox")
    @person = PersonMatcher.find_or_create(display_name: "Sam", email: "sam@example.com",
      viewer: @provisioned[:membership]).person
  end

  teardown { Current.reset }

  test "erasure scrubs the sandbox mail store for that person" do
    MessageSender.send_now!(mailbox: @mailbox, person: @person, subject: "Private subject", body: "sam@example.com details")
    row = SandboxMessage.find_by!(direction: "outbound")
    assert_includes row.mime, "Private subject"

    PersonEraser.call(person: @person)

    row.reload
    assert_nil row.subject
    assert_nil row.mime
    assert_equal PersonEraser::ERASED, row.to_address
    refute_includes PersonEraser.verify(@person.reload), "sandbox_messages"
  end
end
