# frozen_string_literal: true

class OutboxEvent < ApplicationRecord
  include HasUuid
  include TenantScoped

  self.table_name = "outbox_events"

  validates :event_type, :resource_type, :resource_id, :payload, presence: true

  scope :undelivered, -> { where(delivered_at: nil).order(:created_at) }
end
