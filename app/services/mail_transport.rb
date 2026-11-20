# frozen_string_literal: true

# The seam every outbound send and every inbound change goes through. A mailbox
# names its provider; nothing above this module knows which backend is in use.
#
#   deliver!(mailbox:, to:, subject:, body:, thread_id:, in_reply_to:, headers:, message_id:)
#     -> { id:, thread_id:, rfc822_message_id:, ... }
#   find_sent(mailbox:, rfc822_message_id:) -> same hash or nil (idempotent retry)
#
# Backends: Sandbox (stores real RFC 822 inside Bigbuck), Gmail (the GmailClient
# adapter; real Google transport lands with the Gmail track).
module MailTransport
  PROVIDERS = %w[sandbox gmail].freeze

  class << self
    def for(mailbox)
      case mailbox.provider
      when "sandbox" then Sandbox
      when "gmail" then Gmail
      else raise ArgumentError, "unknown_mail_provider"
      end
    end

    def deliver!(mailbox:, to:, subject:, body:, thread_id: nil, in_reply_to: nil, headers: {}, message_id: nil)
      self.for(mailbox).deliver!(mailbox: mailbox, to: to, subject: subject, body: body,
        thread_id: thread_id, in_reply_to: in_reply_to, headers: headers, message_id: message_id)
    end

    def find_sent(mailbox:, rfc822_message_id:)
      self.for(mailbox).find_sent(mailbox: mailbox, rfc822_message_id: rfc822_message_id)
    end

    # RFC 822 ids are stored and compared without angle brackets.
    def normalize_id(value)
      value.to_s.strip.delete_prefix("<").delete_suffix(">").presence
    end
  end
end
