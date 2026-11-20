# frozen_string_literal: true

# The one outbox consumer. Claims undelivered events across tenants with
# FOR UPDATE SKIP LOCKED (so several workers never double-deliver), fans each
# out into one webhook delivery per matching endpoint, and marks it relayed.
# HTTP happens later, in WebhookDispatcher.deliver_due!, outside these locks.
class OutboxRelay
  BATCH = 200
  MAX_PER_RUN = 5_000

  def self.call(batch: BATCH, max: MAX_PER_RUN, organization_id: nil)
    relayed = 0
    loop do
      count = relay_batch(batch, organization_id)
      relayed += count
      break if count < batch || relayed >= max
    end
    relayed
  end

  def self.relay_batch(batch, organization_id = nil)
    OutboxEvent.transaction do
      events = OutboxEvent.unscoped.where(delivered_at: nil)
      events = events.where(organization_id: organization_id) if organization_id
      events = events.order(:created_at).limit(batch)
                          .lock("FOR UPDATE SKIP LOCKED").to_a
      events = events.select { |event| event.organization_id == organization_id } if organization_id
      next 0 if events.empty?

      now = Time.current
      events.group_by(&:organization_id).each { |org_id, org_events| fan_out(org_id, org_events, now) }
      OutboxEvent.unscoped.where(id: events.map(&:id)).update_all(delivered_at: now, updated_at: now)
      events.size
    end
  end

  def self.fan_out(org_id, events, now)
    endpoints = WebhookEndpoint.unscoped.where(organization_id: org_id, active: true).to_a
    return if endpoints.empty?

    rows = events.flat_map do |event|
      endpoints.select { |e| e.accepts?(event.event_type) }.map do |endpoint|
        {
          id: Id.generate, organization_id: org_id, webhook_endpoint_id: endpoint.id,
          outbox_event_id: event.id, event_type: event.event_type, status: "pending",
          attempt_count: 0, next_attempt_at: now, created_at: now, updated_at: now
        }
      end
    end
    # Duplicate (endpoint, event) pairs are skipped by index_webhook_deliveries_once.
    WebhookDelivery.insert_all(rows) if rows.any?
  end

  private_class_method :relay_batch, :fan_out
end
