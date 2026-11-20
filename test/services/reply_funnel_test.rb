# frozen_string_literal: true

require "test_helper"

class ReplyFunnelTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "FunnelCo", slug: "fn-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@fn.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id
    @viewer = @provisioned[:membership]
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@fn.test", provider: "sandbox",
      status: "connected", secret_ref: "sandbox://mailbox", user: @provisioned[:user])
    @sequence = Sequence.find_by!(key: "starter-outreach")
  end

  teardown { Current.reset }

  def person(name, email) = PersonMatcher.find_or_create(display_name: name, email: email, viewer: @viewer).person

  def reply(person, body, subject: "Re: hello", kind: "reply")
    InboundIngestor.call(mailbox: @mailbox, from: person.primary_email, subject: subject, body: body,
      provider_message_id: "pm-#{SecureRandom.hex(4)}", kind: kind)
  end

  test "classifier rules" do
    c = ->(body, subject: "Re: x") { ReplyClassifier.classify(subject: subject, body: body) }
    assert_equal "interested", c.call("Sounds great, let's chat next week")
    assert_equal "interested", c.call(SandboxInbox::BODIES["reply"])
    assert_equal "not_interested", c.call("Thanks but I'm not interested right now")
    assert_equal "unsubscribe", c.call("Please remove me from your list")
    assert_equal "out_of_office", c.call("I am out of office until Monday")
    assert_equal "question", c.call("What is the salary range?")
    assert_equal "other", c.call("Thanks.")
    assert_equal "other", c.call("Thanks.\n\nOn Mon, Jan 1, 2026 at 9:00 AM Rec <rec@x.test> wrote:\n> Are you interested in a role?")
  end

  test "an inbound reply is classified and moves engagement" do
    ana = person("Ana", "ana@fn.test")
    SequenceRunner.enroll!(sequence: @sequence, person: ana, mailbox: @mailbox)
    comm = reply(ana, "Yes, I'd love to chat!")
    assert_equal "interested", comm.reload.classification
    assert_equal "interested", ana.reload.engagement_status
  end

  test "an unsubscribe reply opts the person out" do
    ben = person("Ben", "ben@fn.test")
    reply(ben, "Please unsubscribe me")
    assert ben.reload.do_not_contact
    assert OptOut.blocked?("ben@fn.test")
  end

  test "bounces and auto replies keep their kind labels" do
    cy = person("Cy", "cy@fn.test")
    assert_equal "bounce", reply(cy, "Delivery failed", kind: "bounce").classification
    assert_equal "out_of_office", reply(cy, "I'm away", kind: "auto_reply").classification
  end

  test "funnel counts distinct people and reply labels; snapshots are idempotent" do
    ana = person("Ana", "ana@fn.test")
    ben = person("Ben", "ben@fn.test")
    [ ana, ben ].each { |p| SequenceRunner.enroll!(sequence: @sequence, person: p, mailbox: @mailbox) }
    reply(ana, "Interested, tell me more")
    funnel = OutreachFunnel.call(from: 1.hour.ago, to: 1.hour.from_now, sequence_id: @sequence.id)
    assert_equal 2, funnel["enrolled"]
    assert_equal 2, funnel["contacted"]
    assert_equal 1, funnel["replied"]
    assert_equal 0.5, funnel["reply_rate"]
    assert_equal 1, funnel["by_classification"]["interested"]

    2.times { OutreachSnapshotter.call(day: Date.current) }
    assert_equal 1, OutreachSnapshot.where(scope_key: "org").count
    assert_equal 1, OutreachSnapshot.where(scope_key: "seq:#{@sequence.id}").count
  end

  test "sequence replies only count people contacted in the window" do
    contacted = person("Dana", "dana@fn.test")
    enrolled_only = person("Eli", "eli@fn.test")
    SequenceRunner.enroll!(sequence: @sequence, person: contacted, mailbox: @mailbox)
    SequenceEnrollment.create!(
      sequence: @sequence, person: enrolled_only, mailbox: @mailbox,
      step_index: 0, status: "active"
    )
    reply(enrolled_only, "Interested even though you never emailed me")
    funnel = OutreachFunnel.call(from: 1.hour.ago, to: 1.hour.from_now, sequence_id: @sequence.id)
    assert_equal 1, funnel["contacted"]
    assert_equal 0, funnel["replied"]
  end
end
