# frozen_string_literal: true

module MailTransport
  # Real transport semantics without leaving Bigbuck: builds the same RFC 822
  # message a provider would send and stores it in sandbox_messages.
  module Sandbox
    module_function

    def deliver!(mailbox:, to:, subject:, body:, thread_id: nil, in_reply_to: nil, headers: {}, message_id: nil)
      mail = Message.build(mailbox: mailbox, to: to, subject: subject, body: body,
        in_reply_to: in_reply_to, headers: headers, message_id: message_id)
      id = "sbx_#{SecureRandom.uuid}"
      thread = thread_id.presence || id
      SandboxMessage.create!(
        mailbox: mailbox, direction: "outbound", rfc822_message_id: mail.message_id,
        in_reply_to: MailTransport.normalize_id(in_reply_to), thread_id: thread,
        from_address: mailbox.email, to_address: to, subject: subject,
        mime: mail.to_s, delivered_at: Time.current
      )
      result(id: id, thread_id: thread, rfc822_message_id: mail.message_id,
        from: mailbox.email, to: to, subject: subject, body: body)
    end

    def find_sent(mailbox:, rfc822_message_id:)
      row = SandboxMessage.find_by(mailbox_id: mailbox.id, direction: "outbound",
        rfc822_message_id: MailTransport.normalize_id(rfc822_message_id))
      return nil unless row

      result(id: "sbx_#{row.id}", thread_id: row.thread_id, rfc822_message_id: row.rfc822_message_id,
        from: row.from_address, to: row.to_address, subject: row.subject, body: nil)
    end

    def result(**fields)
      fields.merge(captured: true)
    end
    private_class_method :result
  end
end
