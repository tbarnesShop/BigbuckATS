# frozen_string_literal: true

module Types
  class CustomFieldReferenceValueType < Types::BaseObject
    graphql_name "CustomFieldReferenceValue"
    implements Types::CustomFieldValueType

    field :reference_id, ID, null: true
    field :reference_type, String, null: true

    def reference_type = object.custom_field.reference_type

    def reference_id
      value = object.typed_value
      value
    end
  end
end
