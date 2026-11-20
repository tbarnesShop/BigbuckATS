# frozen_string_literal: true

# Sends due webhook deliveries and retries failed ones with backoff.
class DeliverWebhooksJob < ApplicationJob
  queue_as :webhooks

  def perform(limit: 100)
    WebhookDispatcher.deliver_due!(limit: limit)
  end
end
