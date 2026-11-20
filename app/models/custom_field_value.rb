# frozen_string_literal: true

class CustomFieldValue < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :custom_field

  validates :entity_type, :entity_id, presence: true

  # The typed Ruby value, read with the field's current type.
  def typed_value
    CustomFieldTypes.read(self, custom_field.field_type)
  end
end
