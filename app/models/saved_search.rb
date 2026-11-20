# frozen_string_literal: true

class SavedSearch < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :name, :user_id, :entity_type, :filters, presence: true
  validates :entity_type, inclusion: { in: %w[person] }
end
