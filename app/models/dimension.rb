# frozen_string_literal: true

class Dimension < ApplicationRecord
  include HasUuid
  include TenantScoped

  has_many :dimension_values, dependent: :destroy

  validates :key, :label, presence: true
  validates :key, uniqueness: { scope: :organization_id }

  def applies_to_list
    Array(applies_to)
  end
end
