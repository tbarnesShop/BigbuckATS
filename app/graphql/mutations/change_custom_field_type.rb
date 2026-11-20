# frozen_string_literal: true

module Mutations
  class ChangeCustomFieldType < CustomFieldMutation
    description "Convert a field and all its stored values to another type. Preview first with customFieldTypeChangePreview."
    permission "custom_field.manage"

    argument :id, ID, required: true
    argument :to_type, String, required: true
    argument :options, [ Types::CustomFieldOptionInput ], required: false
    argument :reference_type, String, required: false
    argument :on_unconvertible, Types::UnconvertibleStrategyEnum, required: false, default_value: "refuse"
    argument :expected_version, Integer, required: false

    field :field, Types::CustomFieldDefinitionType, null: true

    def resolve(id:, to_type:, on_unconvertible:, options: nil, reference_type: nil, expected_version: nil)
      guarded do
        field = CustomFieldDefinitions.change_type!(
          CustomField.find(id), to_type: to_type, options: options&.map(&:to_h), reference_type: reference_type,
                                on_unconvertible: on_unconvertible, expected_version: expected_version
        )
        { field: field, user_errors: [] }
      end
    end
  end
end
