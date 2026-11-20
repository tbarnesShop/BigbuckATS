# frozen_string_literal: true

class DimensionValue < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :dimension
  belongs_to :parent, class_name: "DimensionValue", optional: true
  has_many :children, class_name: "DimensionValue", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_exception

  validates :key, :label, presence: true
  validates :key, uniqueness: { scope: %i[organization_id dimension_id] }

  # JSON attributes on the value (e.g. department.head user id). Column is
  # attributes_json because ActiveRecord reserves `attributes`.
  def value_attributes
    (attributes_json || {}).deep_stringify_keys
  end

  def value_attributes=(hash)
    self.attributes_json = hash
  end

  def self_and_descendant_ids
    ids = [ id ]
    queue = [ id ]
    while queue.any?
      kids = DimensionValue.where(parent_id: queue).pluck(:id)
      break if kids.empty?

      ids.concat(kids)
      queue = kids
    end
    ids
  end
end
