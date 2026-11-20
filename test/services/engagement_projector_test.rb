# frozen_string_literal: true

require "test_helper"

class EngagementProjectorTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "EngCo", slug: "e-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@e.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@e.test", provider: "sandbox", status: "connected",
      secret_ref: "sandbox://mailbox", user: @provisioned[:user])
    @person = PersonMatcher.find_or_create(display_name: "Eve", email: "eve@example.com",
      viewer: @provisioned[:membership], source: "sourced").person
  end

  teardown { Current.reset }

  def enroll! = SequenceRunner.enroll!(sequence: Sequence.find_by!(key: "starter-outreach"), person: @person, mailbox: @mailbox)

  test "a new person is not contacted and remembers where they came from" do
    assert_equal "not_contacted", @person.engagement_status
    assert_equal "sourced", @person.source
    assert_equal @provisioned[:user].id, @person.sourced_by_user_id
    assert @person.sourced_at
  end

  test "a send marks them contacted, a reply marks them replied" do
    enroll!
    @person.reload
    assert_equal "contacted", @person.engagement_status
    assert @person.last_contacted_at
    assert_nil @person.last_replied_at

    SandboxInbox.answer!(message: SandboxMessage.find_by!(direction: "outbound"), kind: "reply")
    @person.reload
    # The Test inbox reply ("open to a quick chat") is classified interested, which supersedes replied.
    assert_equal "interested", @person.engagement_status
    assert @person.last_replied_at
    assert_operator @person.last_activity_at, :>=, @person.last_contacted_at
  end

  test "an out-of-office counts as activity but not a reply" do
    enroll!
    SandboxInbox.answer!(message: SandboxMessage.find_by!(direction: "outbound"), kind: "auto_reply")
    assert_equal "contacted", @person.reload.engagement_status
    assert_nil @person.last_replied_at
  end

  test "a decision is never overwritten by later traffic" do
    @person.update!(engagement_status: "not_interested")
    enroll!
    SandboxInbox.answer!(message: SandboxMessage.find_by!(direction: "outbound"), kind: "auto_reply")
    assert_equal "not_interested", @person.reload.engagement_status
  end

  test "do not contact wins, and clearing it returns to what the history shows" do
    enroll!
    @person.reload.update!(do_not_contact: true)
    assert_equal "do_not_contact", @person.engagement_status
    @person.update!(do_not_contact: false)
    assert_equal "contacted", @person.engagement_status
  end

  test "source is set once" do
    @person.source = "referral"
    assert_not @person.valid?
    assert_includes @person.errors[:source].join, "cannot change"
  end
end
