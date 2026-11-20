# frozen_string_literal: true

require "test_helper"

class InboundIngestorTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "InCo", slug: "in-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@in.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@in.test", provider: "sandbox",
      status: "connected", secret_ref: "sandbox://mailbox")
    MessageTemplate.create!(key: "intro", message_type: "sequence", subject: "Hi {{ person.display_name }}", body: "Chat?")
    @sequence = Sequence.create!(key: "seq", name: "Seq", steps: [ { "type" => "email", "template_key" => "intro" }, { "type" => "wait", "days" => 3 } ])
    @person = PersonMatcher.find_or_create(display_name: "Prospect", email: "prospect@example.com",
      viewer: @provisioned[:membership]).person
    @enrollment = SequenceRunner.enroll!(sequence: @sequence, person: @person, mailbox: @mailbox)
    @outbound = Communication.find_by!(person_id: @person.id, direction: "outbound")
  end

  teardown { Current.reset }

  def ingest(**args)
    InboundIngestor.call(mailbox: @mailbox, from: "prospect@example.com", subject: "Re: Hi", body: "Sure",
      provider_message_id: "in-#{SecureRandom.hex(4)}", **args)
  end

  test "outbound send through the sandbox records the RFC 822 id on the communication" do
    assert @outbound.rfc822_message_id.present?
    assert SandboxMessage.exists?(rfc822_message_id: @outbound.rfc822_message_id, direction: "outbound")
  end

  test "a reply from a new address lands on the thread via In-Reply-To" do
    comm = ingest(from: "personal-gmail@example.org", in_reply_to: "<#{@outbound.rfc822_message_id}>")
    assert_equal @person.id, comm.person_id
    assert_equal @outbound.thread_id, comm.thread_id
    assert_equal "stopped", @enrollment.reload.status
    assert_equal "reply", @enrollment.stop_reason
  end

  test "a reply lands on the thread by thread id alone" do
    comm = ingest(from: "someone-else@example.org", thread_id: @outbound.thread_id)
    assert_equal @person.id, comm.person_id
  end

  test "with no thread information the sender decides" do
    assert_equal @person.id, ingest.person_id
  end

  test "an unknown sender with no thread is ignored" do
    assert_nil ingest(from: "stranger@example.org")
  end

  test "ingesting the same provider message twice is a no-op" do
    first = ingest(provider_message_id: "dup-1")
    assert_no_difference -> { Communication.count } do
      assert_equal first.id, ingest(provider_message_id: "dup-1").id
    end
  end

  test "a bounce stops the enrollment with reason bounce and is classified" do
    comm = ingest(kind: "bounce", in_reply_to: @outbound.rfc822_message_id)
    assert_equal "bounce", comm.classification
    assert_equal "bounce", @enrollment.reload.stop_reason
  end

  test "an out-of-office reply is recorded but does not stop the sequence" do
    comm = ingest(kind: "auto_reply", in_reply_to: @outbound.rfc822_message_id)
    assert_equal "out_of_office", comm.classification
    assert_equal "active", @enrollment.reload.status
  end

  test "an erased person receives nothing" do
    @person.update_columns(erased_at: Time.current)
    assert_nil ingest
  end

  test "unknown inbound kinds are rejected" do
    assert_raises(ArgumentError) { ingest(kind: "spam") }
  end

  test "the legacy MailSync entry still works" do
    comm = MailSync.ingest_inbound!(mailbox: @mailbox, from: "prospect@example.com", subject: "Re:", body: "ok",
      thread_id: @outbound.thread_id, provider_message_id: "legacy-1")
    assert_equal @person.id, comm.person_id
  end
end
