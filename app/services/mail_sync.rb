# frozen_string_literal: true

# Compatibility entry for inbound mail. The logic lives in InboundIngestor.
class MailSync
  def self.ingest_inbound!(mailbox:, from:, subject:, body:, thread_id:, provider_message_id:, **extra)
    InboundIngestor.call(mailbox: mailbox, from: from, subject: subject, body: body,
      thread_id: thread_id, provider_message_id: provider_message_id, **extra)
  end
end
