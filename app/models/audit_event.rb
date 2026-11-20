# frozen_string_literal: true

class AuditEvent < ApplicationRecord
  include HasUuid
  include TenantScoped

  self.table_name = "audit_events"

  validates :action, :resource_type, :resource_id, presence: true
end
