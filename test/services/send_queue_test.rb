# frozen_string_literal: true

require "test_helper"

class SendQueueTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "QueueCo", slug: "q-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@q.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    Current.organization_id = @org.id
    Current.actor_id = @provisioned[:user].id
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@q.test", provider: "sandbox",
      status: "connected", secret_ref: "sandbox://mailbox", user: @provisioned[:user])
    @person = PersonMatcher.find_or_create(display_name: "Pat", email: "pat@example.com",
      viewer: @provisioned[:membership]).person
    @sequence = Sequence.find_by!(key: "starter-outreach")
  end

  teardown { Current.reset }

  test "new orgs start with a working default sequence" do
    assert_equal %w[email wait email], @sequence.steps.map { |s| s["type"] }
    assert MessageTemplate.exists?(key: "starter-intro")
  end

  test "an enrollment sends through the queue with unsubscribe footer and headers" do
    enrollment = SequenceRunner.enroll!(sequence: @sequence, person: @person, mailbox: @mailbox)
    message = ScheduledMessage.find_by!(sequence_enrollment_id: enrollment.id)
    assert_equal "sent", message.status
    row = SandboxMessage.find_by!(rfc822_message_id: message.rfc822_message_id)
    assert_includes row.mime, "List-Unsubscribe: <"
    assert_includes row.mime, "List-Unsubscribe-Post: List-Unsubscribe=One-Click"
    assert_includes row.mime, "/unsubscribe/"
  end

  test "outside the sending window the message waits, then goes when the window opens" do
    @org.update!(settings: { "send_window" => { "enabled" => true, "start_hour" => 9, "end_hour" => 17,
                                                  "days" => [ 1, 2, 3, 4, 5 ], "timezone" => "UTC" } })
    saturday = Time.utc(2026, 11, 7, 12, 0)
    enrollment = SequenceEnrollment.create!(sequence: @sequence, person: @person, mailbox: @mailbox, step_index: 0, status: "active")
    message = SendQueue.enqueue!(enrollment: enrollment, template: MessageTemplate.find_by!(key: "starter-intro"), send_at: saturday)
    SendQueue.process!(message, now: saturday)
    assert_equal "queued", message.reload.status
    assert_equal "outside_window", message.defer_reason
    assert_equal Time.utc(2026, 11, 9, 9, 0), message.send_at

    SendQueue.process!(message, now: Time.utc(2026, 11, 9, 9, 1))
    assert_equal "sent", message.reload.status
  end

  test "a reached daily cap defers to tomorrow instead of failing" do
    @mailbox.update!(daily_cap: 0)
    enrollment = SequenceEnrollment.create!(sequence: @sequence, person: @person, mailbox: @mailbox, step_index: 0, status: "active")
    message = SendQueue.enqueue!(enrollment: enrollment, template: MessageTemplate.find_by!(key: "starter-intro"))
    SendQueue.process!(message)
    assert_equal "queued", message.reload.status
    assert_equal "mailbox_cap_reached", message.defer_reason
    assert_operator message.send_at, :>, Time.current
  end

  test "a retry after a send that was recorded at the transport does not send twice" do
    enrollment = SequenceEnrollment.create!(sequence: @sequence, person: @person, mailbox: @mailbox, step_index: 0, status: "active")
    message = SendQueue.enqueue!(enrollment: enrollment, template: MessageTemplate.find_by!(key: "starter-intro"))
    SendQueue.process!(message)
    message.update!(status: "queued") # simulate a crash after delivery but before the status write
    SendQueue.process!(message)
    assert_equal "sent", message.reload.status
    assert_equal 1, SandboxMessage.where(direction: "outbound", rfc822_message_id: message.rfc822_message_id).count
    assert_equal 1, Communication.where(rfc822_message_id: message.rfc822_message_id).count
  end

  test "stopping an enrollment cancels what is queued" do
    enrollment = SequenceEnrollment.create!(sequence: @sequence, person: @person, mailbox: @mailbox, step_index: 0, status: "active")
    message = SendQueue.enqueue!(enrollment: enrollment, template: MessageTemplate.find_by!(key: "starter-intro"),
      send_at: 1.day.from_now)
    enrollment.stop!("reply")
    assert_equal "cancelled", message.reload.status
  end

  test "tick sends due messages across the queue" do
    enrollment = SequenceEnrollment.create!(sequence: @sequence, person: @person, mailbox: @mailbox, step_index: 0, status: "active")
    message = SendQueue.enqueue!(enrollment: enrollment, template: MessageTemplate.find_by!(key: "starter-intro"))
    assert_equal 1, SendQueue.tick!
    assert_equal "sent", message.reload.status
  end

  test "stop rules: do-not-contact, active application and hire end sequences" do
    enrollment = SequenceRunner.enroll!(sequence: @sequence, person: @person, mailbox: @mailbox)
    @person.reload.update!(do_not_contact: true)
    assert_equal [ "stopped", "do_not_contact" ], [ enrollment.reload.status, enrollment.stop_reason ]

    other = PersonMatcher.find_or_create(display_name: "Quinn", email: "quinn@example.com", viewer: @provisioned[:membership]).person
    e2 = SequenceEnrollment.create!(sequence: @sequence, person: other, mailbox: @mailbox, step_index: 1, status: "active")
    EnrollmentStopper.call(person: other, reason: "active_application")
    assert_equal "active_application", e2.reload.stop_reason
  end

  test "an opted-out address cannot be enrolled, even after the person is erased" do
    OptOut.add!(person: @person, source: "unsubscribe_link")
    assert OptOut.blocked?("PAT@example.com")
    assert_raises(ArgumentError) { SequenceRunner.enroll!(sequence: @sequence, person: @person, mailbox: @mailbox) }
  end
end
