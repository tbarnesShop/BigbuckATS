# frozen_string_literal: true

# The one path every sequence email takes: enqueue a rendered ScheduledMessage, then deliver when
# the sending window, the mailbox cap and the stop rules allow. A retry never double-sends: the
# Message-ID is generated at enqueue time and the transport is asked whether it already sent it.
class SendQueue
  LEASE = 10.minutes
  MAX_ATTEMPTS = 5

  def self.enqueue!(enrollment:, template:, send_at: Time.current, step_id: nil, send_as_user_id: nil)
    person = enrollment.person
    mailbox = (send_as_user_id.present? && Mailbox.where(user_id: send_as_user_id).order(:created_at).first) || enrollment.mailbox
    tokens = MessageTokens.for(person: person, sender: mailbox&.user, sender_email: mailbox&.email, extra: enrollment.merge_fields)
    ScheduledMessage.create!(
      mailbox: mailbox,
      sequence_step_id: step_id,
      person: person,
      sequence_enrollment_id: enrollment.id,
      template_key: template.key,
      message_type: template.message_type,
      subject: MessageRenderer.render(template.subject, tokens, escape: false),
      body: MessageRenderer.render(template.body, tokens, escape: false),
      status: "queued",
      send_at: send_at,
      rfc822_message_id: "#{SecureRandom.uuid}@bigbuck.local"
    )
  end

  # Claims due rows across organizations and processes each under its tenant.
  def self.tick!(now: Time.current, limit: 200)
    claimed = ScheduledMessage.transaction do
      rows = ScheduledMessage.unscoped.where(status: "queued").where("send_at <= ?", now)
                             .order(:send_at).limit(limit).lock("FOR UPDATE SKIP LOCKED").to_a
      ScheduledMessage.unscoped.where(id: rows.map(&:id)).update_all(send_at: now + LEASE, updated_at: now)
      rows
    end
    claimed.each do |row|
      Current.set(organization_id: row.organization_id, actor_type: "system", source_surface: "automation") do
        process!(ScheduledMessage.find(row.id), now: now)
      end
    end
    claimed.size
  end

  # Decides one message: cancel, defer, retry-later or send. Returns the message.
  def self.process!(message, now: Time.current)
    return message unless message.status == "queued"

    cancel = cancel_reason(message)
    return finish(message, "cancelled", defer_reason: cancel) if cancel

    org = Organization.find(message.organization_id)
    opens = SendWindow.next_allowed(org, now)
    return defer(message, opens, "outside_window") if opens > now

    deliver(message, now)
  end

  def self.cancel_reason(message)
    enrollment = SequenceEnrollment.find_by(id: message.sequence_enrollment_id)
    return "enrollment_stopped" if enrollment && !enrollment.active?

    person = message.person
    return "do_not_contact" if person.do_not_contact || OptOut.blocked?(person.primary_email)

    nil
  end

  def self.deliver(message, now)
    enrollment = SequenceEnrollment.find_by(id: message.sequence_enrollment_id)
    communication = MessageSender.send_now!(
      mailbox: message.mailbox, person: message.person, subject: message.subject, body: message.body,
      message_type: message.message_type, enrollment: enrollment, message_id: message.rfc822_message_id,
      unsubscribe: true
    )
    message.update!(status: "sent", sent_at: now, communication_id: communication.id, last_error: nil, defer_reason: nil)
    message
  rescue ArgumentError => e
    handle_failure(message, e, now)
  rescue StandardError => e
    handle_failure(message, e, now, retryable: true)
  end

  def self.handle_failure(message, error, now, retryable: false)
    case error.message
    when "mailbox_cap_reached"
      defer(message, now.in_time_zone.tomorrow.beginning_of_day.utc, "mailbox_cap_reached")
    when "mailbox_not_connected"
      defer(message, now + 1.hour, "mailbox_not_connected")
    else
      attempts = message.attempts + 1
      if attempts >= MAX_ATTEMPTS || !retryable
        message.update!(status: "failed", attempts: attempts, last_error: error.message.truncate(250))
      else
        message.update!(attempts: attempts, last_error: error.message.truncate(250), send_at: now + (2**attempts).minutes)
      end
      message
    end
  end

  def self.defer(message, send_at, reason)
    message.update!(send_at: send_at, defer_reason: reason)
    message
  end

  def self.finish(message, status, defer_reason: nil)
    message.update!(status: status, defer_reason: defer_reason)
    message
  end

  private_class_method :cancel_reason, :deliver, :handle_failure, :defer, :finish
end
