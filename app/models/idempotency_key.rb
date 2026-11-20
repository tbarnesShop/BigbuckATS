# frozen_string_literal: true

class IdempotencyKey < ApplicationRecord
  include HasUuid
  include TenantScoped

  self.table_name = "idempotency_keys"

  validates :key, :request_path, :request_method, presence: true
  validates :key, uniqueness: { scope: :organization_id }
end
