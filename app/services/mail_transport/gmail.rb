# frozen_string_literal: true

module MailTransport
  # Gmail provider: delegates to the GmailClient adapter (demo capture, test
  # fake, or the real backend once the Gmail track is wired).
  module Gmail
    module_function

    def deliver!(mailbox:, to:, subject:, body:, thread_id: nil, in_reply_to: nil, headers: {}, message_id: nil)
      GmailClient.send_message!(mailbox: mailbox, to: to, subject: subject, body: body,
        thread_id: thread_id, in_reply_to: in_reply_to, headers: headers, message_id: message_id)
    end

    def find_sent(mailbox:, rfc822_message_id:)
      backend = GmailClient.backend
      return nil unless backend.respond_to?(:find_sent)

      backend.find_sent(mailbox: mailbox, rfc822_message_id: rfc822_message_id)
    end
  end
end
