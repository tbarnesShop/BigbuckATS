# frozen_string_literal: true

# action_mailer/railtie loads the mail gem lazily; a plain Puma process never touches ActionMailer::Base.
require "mail"

module MailTransport
  # Builds a real RFC 822 message (Message-ID, threading headers, extra headers
  # such as List-Unsubscribe) so every backend sends the same thing.
  module Message
    module_function

    def build(mailbox:, to:, subject:, body:, in_reply_to: nil, headers: {}, message_id: nil)
      domain = mailbox.email.to_s.split("@", 2).last.presence || "bigbuck.local"
      mail = Mail.new
      mail.from = mailbox.email
      mail.to = to
      mail.subject = subject
      mail.charset = "UTF-8"
      mail.body = body.to_s
      mail.message_id = MailTransport.normalize_id(message_id) || "#{SecureRandom.uuid}@#{domain}"
      if (reply_to = MailTransport.normalize_id(in_reply_to))
        mail.in_reply_to = reply_to
        mail.references = reply_to
      end
      headers.each { |name, value| mail[name.to_s] = value.to_s }
      mail
    end
  end
end
