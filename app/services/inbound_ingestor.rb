# frozen_string_literal: true

# The one door for inbound mail, whatever the backend (Sandbox Test inbox, the
# REST inbound hook, Gmail sync later). Matches the person on the thread first
# (In-Reply-To, then thread id) and the sender second, so a reply from a new
# address on a known thread still lands. Idempotent on provider_message_id.
#
# kind: "reply" stops the person's active enrollments; "bounce" stops them with
# reason bounce; "auto_reply" is recorded and classified out_of_office without
# stopping anything.
class InboundIngestor
  KINDS = %w[reply bounce auto_reply].freeze
  CLASSIFICATIONS = { "bounce" => "bounce", "auto_reply" => "out_of_office" }.freeze

  def self.call(**args)
    new(**args).call
  end

  def initialize(mailbox:, from:, subject:, body:, provider_message_id:, thread_id: nil,
                 rfc822_message_id: nil, in_reply_to: nil, kind: "reply")
    raise ArgumentError, "unknown_inbound_kind" unless KINDS.include?(kind.to_s)

    @mailbox = mailbox
    @from = from
    @subject = subject
    @body = body
    @provider_message_id = provider_message_id
    @thread_id = thread_id.presence
    @rfc822_message_id = MailTransport.normalize_id(rfc822_message_id)
    @in_reply_to = MailTransport.normalize_id(in_reply_to)
    @kind = kind.to_s
  end

  def call
    existing = Communication.find_by(provider_message_id: @provider_message_id)
    return existing if existing

    person = match_person
    return nil if person.nil? || person.erased?

    ActiveRecord::Base.transaction do
      communication = Communication.create!(
        person: person, mailbox: @mailbox, direction: "inbound", channel: "email",
        subject: @subject, body: @body, provider_message_id: @provider_message_id,
        thread_id: @thread_id || thread_of(person), rfc822_message_id: @rfc822_message_id,
        in_reply_to: @in_reply_to, classification: CLASSIFICATIONS[@kind], status: "received"
      )
      stop_enrollments!(person)
      result = ChangeWriter.call(
        record: communication,
        action: "communication.received",
        event_type: "communication.received",
        payload: {
          "person_id" => person.id, "mailbox" => @mailbox.email, "subject" => @subject,
          "direction" => "inbound", "kind" => @kind
        }
      )
      TimelineProjector.call(outbox_event: result.outbox_event)
      classify!(communication) if @kind == "reply"
      communication
    end
  end

  private

  def classify!(communication)
    ReplyClassifier.apply!(communication, ReplyClassifier.classify(subject: communication.subject, body: communication.body))
  end

  def match_person
    by_reference || by_thread || by_sender
  end

  def by_reference
    return unless @in_reply_to

    Communication.where(mailbox_id: @mailbox.id, rfc822_message_id: @in_reply_to).order(created_at: :desc).first&.person
  end

  def by_thread
    return unless @thread_id

    Communication.where(mailbox_id: @mailbox.id, thread_id: @thread_id).order(created_at: :desc).first&.person
  end

  def by_sender
    Person.joins(:contact_points).find_by(
      person_contact_points: { kind: "email", normalized_value: PersonContactPoint.normalize_email(@from) }
    )
  end

  def thread_of(person)
    return unless @in_reply_to

    Communication.where(person_id: person.id, rfc822_message_id: @in_reply_to).pick(:thread_id)
  end

  def stop_enrollments!(person)
    return if @kind == "auto_reply"

    SequenceEnrollment.where(person_id: person.id, status: "active").find_each do |enrollment|
      enrollment.stop!(@kind == "bounce" ? "bounce" : "reply")
    end
  end
end
