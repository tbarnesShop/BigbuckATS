# frozen_string_literal: true

class EntityDimensionValue < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :dimension
  belongs_to :dimension_value

  validates :entity_type, :entity_id, presence: true
end
