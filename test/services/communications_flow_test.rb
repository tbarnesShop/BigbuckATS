# frozen_string_literal: true

require "test_helper"

# M4 proving test: sequence from personal Gmail, reply stops it,
# confirmation from shared recruiting@, timeline shows all three.
class CommunicationsFlowTest < ActiveSupport::TestCase
  setup do
    @fake = GmailClient::Fake.new
    GmailClient.backend = @fake

    @provisioned = OrganizationProvisioner.call(
      name: "MailCo", slug: "mail-#{SecureRandom.hex(3)}",
      owner_email: "owner-#{SecureRandom.hex(3)}@mail.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id

    @personal = Mailbox.create!(
      kind: "personal", email: "sourcer@mail.test",
      user: @provisioned[:user], status: "connected", secret_ref: "sm://personal"
    )
    @shared = Mailbox.create!(
      kind: "shared", email: "recruiting@mail.test",
      status: "connected", secret_ref: "sm://shared"
    )

    MessageTemplate.create!(
      key: "outreach-1", message_type: "sequence",
      subject: "Hi {{ person.display_name }}",
      body: "Interested in chatting, {{ person.display_name }}?"
    )
    MessageTemplate.create!(
      key: "application-confirmation", message_type: "confirmation",
      subject: "We received your application",
      body: "Thanks {{ person.display_name }}"
    )

    @sequence = Sequence.create!(
      key: "default-outreach", name: "Default",
      steps: [ { "type" => "email", "template_key" => "outreach-1" } ]
    )

    @person = PersonMatcher.find_or_create(
      display_name: "Prospect", email: "prospect@example.com",
      viewer: @provisioned[:membership]
    ).person
  end

  teardown do
    GmailClient.backend = nil
    Current.reset
  end

  test "sequence send, reply stops it, confirmation, timeline has all three" do
    enrollment = SequenceRunner.enroll!(sequence: @sequence, person: @person, mailbox: @personal)
    assert_equal 1, @fake.sent.size
    assert_equal "sourcer@mail.test", @fake.sent.first[:from]
    outreach = Communication.find_by!(direction: "outbound", message_type: "sequence")

    MailSync.ingest_inbound!(
      mailbox: @personal,
      from: "prospect@example.com",
      subject: "Re: Hi Prospect",
      body: "Sure, let's talk",
      thread_id: outreach.thread_id,
      provider_message_id: "reply_1"
    )
    assert_equal "stopped", enrollment.reload.status
    assert_equal "reply", enrollment.stop_reason

    MessageSender.send_now!(
      mailbox: @shared,
      person: @person,
      subject: MessageRenderer.render("We received your application", {}),
      body: MessageRenderer.render("Thanks {{ person.display_name }}", { "person.display_name" => @person.display_name }),
      message_type: "confirmation"
    )
    assert_equal "recruiting@mail.test", @fake.sent.last[:from]

    events = TimelineEvent.where(person_id: @person.id).order(:occurred_at)
    types = events.map(&:event_type)
    assert_includes types, "communication.sent"
    assert_includes types, "communication.received"
    assert_equal 3, events.size # outreach sent, reply received, confirmation sent
  end
end
