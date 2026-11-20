# frozen_string_literal: true

class MessageSender
  def self.send_now!(**args)
    new(**args).send_now!
  end

  # unsubscribe: true appends the opt-out footer and List-Unsubscribe headers (bulk/sequence mail).
  # message_id: a pre-generated RFC 822 id; with it a retry finds the earlier delivery instead of resending.
  def initialize(mailbox:, person:, subject:, body:, message_type: nil, enrollment: nil, thread_id: nil, in_reply_to: nil,
                 headers: {}, message_id: nil, unsubscribe: false)
    @thread_id = thread_id
    @in_reply_to = in_reply_to
    @headers = headers
    @mailbox = mailbox
    @person = person
    @subject = subject
    @body = body
    @message_type = message_type
    @enrollment = enrollment
    @message_id = message_id
    @unsubscribe = unsubscribe
  end

  def send_now!
    raise ArgumentError, "person has no email" if @person.primary_email.blank?
    ConsentGate.check!(person: @person, action: "communication.send")

    body = @body
    headers = @headers.dup
    if @unsubscribe
      token = UnsubscribeToken.issue(@person)
      body = "#{@body}\n\n--\nNot interested? Unsubscribe: #{UnsubscribeToken.web_url(token)}"
      headers["List-Unsubscribe"] = "<#{UnsubscribeToken.api_url(token)}>"
      headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    end

    ActiveRecord::Base.transaction do
      previous = @message_id && MailTransport.find_sent(mailbox: @mailbox, rfc822_message_id: @message_id)
      unless previous
        @mailbox.reserve_send!
        previous = MailTransport.deliver!(
          mailbox: @mailbox, to: @person.primary_email, subject: @subject, body: body,
          thread_id: @thread_id, in_reply_to: @in_reply_to, headers: headers, message_id: @message_id
        )
      end
      record_communication(previous, body)
    end
  end

  private

  def record_communication(result, body)
    existing = @message_id && Communication.find_by(rfc822_message_id: MailTransport.normalize_id(@message_id))
    return existing if existing

    communication = Communication.create!(
      person: @person, mailbox: @mailbox, direction: "outbound", channel: "email",
      subject: @subject, body: body,
      provider_message_id: result[:id], thread_id: result[:thread_id], rfc822_message_id: result[:rfc822_message_id],
      in_reply_to: MailTransport.normalize_id(@in_reply_to),
      sequence_enrollment_id: @enrollment&.id, message_type: @message_type, status: "sent"
    )
    outcome = ChangeWriter.call(
      record: communication, action: "communication.sent", event_type: "communication.sent",
      payload: {
        "person_id" => @person.id, "mailbox" => @mailbox.email, "subject" => @subject,
        "message_type" => @message_type, "direction" => "outbound"
      }
    )
    TimelineProjector.call(outbox_event: outcome.outbox_event)
    communication
  end
end
