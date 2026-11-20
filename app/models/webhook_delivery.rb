# frozen_string_literal: true

class WebhookDelivery < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :webhook_endpoint

  validates :outbox_event_id, :event_type, :status, presence: true
end
