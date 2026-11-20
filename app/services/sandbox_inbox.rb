# frozen_string_literal: true

# The Test inbox. A recruiter (or a task) answers what a Test mailbox sent, as if the candidate had:
# the answer is stored as an inbound SandboxMessage and goes through the same InboundIngestor door as
# Gmail or the REST hook, so stop rules, bounce handling and classification run for real.
class SandboxInbox
  BODIES = {
    "reply" => "Thanks for reaching out. I'd be open to a quick chat.",
    "bounce" => "Delivery to this address failed: the mailbox does not exist (550 5.1.1).",
    "auto_reply" => "I'm out of the office and will reply when I'm back."
  }.freeze

  SUBJECT_PREFIX = { "reply" => "Re: ", "bounce" => "Undeliverable: ", "auto_reply" => "Automatic reply: " }.freeze

  def self.answer!(message:, kind:, body: nil)
    new(message: message, kind: kind, body: body).call
  end

  # Answers the newest unanswered outbound message of up to `limit` people, for demos and bulk tests.
  def self.answer_unanswered!(mailbox:, kind: "reply", limit: 10)
    answered = SandboxMessage.where(mailbox_id: mailbox.id, direction: "inbound").select(:in_reply_to)
    SandboxMessage.where(mailbox_id: mailbox.id, direction: "outbound").where.not(rfc822_message_id: answered)
                  .order(delivered_at: :desc).limit(limit).map { |m| answer!(message: m, kind: kind) }
  end

  def initialize(message:, kind:, body:)
    raise ArgumentError, "not_a_sandbox_mailbox" unless message.mailbox.sandbox?
    raise ArgumentError, "can_only_answer_sent_mail" unless message.direction == "outbound"
    raise ArgumentError, "unknown_inbound_kind" unless InboundIngestor::KINDS.include?(kind.to_s)

    @message = message
    @kind = kind.to_s
    @body = body.presence || BODIES.fetch(@kind)
  end

  def call
    mailbox = @message.mailbox
    inbound = SandboxMessage.create!(
      mailbox: mailbox, direction: "inbound",
      rfc822_message_id: "#{SecureRandom.uuid}@sandbox.bigbuck.local",
      in_reply_to: @message.rfc822_message_id, thread_id: @message.thread_id,
      from_address: @message.to_address, to_address: mailbox.email,
      subject: "#{SUBJECT_PREFIX.fetch(@kind)}#{@message.subject}", mime: @body, delivered_at: Time.current
    )
    InboundIngestor.call(
      mailbox: mailbox, from: inbound.from_address, subject: inbound.subject, body: @body,
      provider_message_id: "sbx_in_#{inbound.id}", thread_id: inbound.thread_id,
      rfc822_message_id: inbound.rfc822_message_id, in_reply_to: inbound.in_reply_to, kind: @kind
    )
    inbound
  end
end
