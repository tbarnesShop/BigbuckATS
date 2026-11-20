# frozen_string_literal: true

# Fans out new outbox events into webhook deliveries (recurring, every few seconds).
class RelayOutboxJob < ApplicationJob
  queue_as :outbox

  def perform
    relayed = OutboxRelay.call
    DeliverWebhooksJob.perform_later if relayed.positive?
  end
end
