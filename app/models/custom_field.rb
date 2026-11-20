# frozen_string_literal: true

# A custom field definition. Definitions are versioned (CustomFieldVersion) and
# archived, never deleted, so stored values always keep a definition to be read
# against. Change definitions through CustomFieldDefinitions.
class CustomField < ApplicationRecord
  include HasUuid
  include TenantScoped

  DATA_CLASSES = %w[pii sensitive internal].freeze
  STATUSES = %w[active archived].freeze
  ENTITIES = %w[person job application offer project company].freeze

  has_many :custom_field_values, dependent: :restrict_with_exception
  has_many :versions, -> { order(:version) }, class_name: "CustomFieldVersion", dependent: :restrict_with_exception

  validates :entity, :key, :label, :field_type, :data_class, :status, presence: true
  validates :data_class, inclusion: { in: DATA_CLASSES }
  validates :status, inclusion: { in: STATUSES }
  validates :field_type, inclusion: { in: CustomFieldTypes::ALL }
  validates :key, uniqueness: { scope: %i[organization_id entity] }, format: { with: /\A[a-z][a-z0-9_-]*\z/ }
  validate :options_match_type

  scope :for_offer, -> { where(entity: "offer") }
  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def option_keys
    Array(options).map { |o| o.is_a?(Hash) ? (o["key"] || o[:key]).to_s : o.to_s }
  end

  # The definition as recorded in each version row.
  def definition_snapshot
    {
      "key" => key, "entity" => entity, "label" => label, "description" => description,
      "field_type" => field_type, "data_class" => data_class, "options" => options,
      "reference_type" => reference_type, "required" => required, "filterable" => filterable,
      "display_order" => display_order, "visibility_roles" => visibility_roles, "status" => status,
      "show_on_apply" => show_on_apply
    }
  end

  # Visible to this principal? visibility_roles limits a field to some roles.
  def visible_to?(principal)
    roles = Array(visibility_roles).map(&:to_s)
    return true if roles.empty? || principal.nil?

    role_key = principal.membership&.role&.key
    role_key.present? && roles.include?(role_key)
  end

  private

  def options_match_type
    if CustomFieldTypes.option_type?(field_type)
      errors.add(:options, "are required for #{field_type} fields") if option_keys.empty?
      errors.add(:options, "must be unique") if option_keys.uniq.size != option_keys.size
    end
    if field_type == "reference" && !CustomFieldTypes::REFERENCE_TYPES.include?(reference_type.to_s)
      errors.add(:reference_type, "must be one of #{CustomFieldTypes::REFERENCE_TYPES.join(', ')}")
    end
  end
end
