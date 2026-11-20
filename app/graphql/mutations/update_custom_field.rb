# frozen_string_literal: true

module Mutations
  class UpdateCustomField < CustomFieldMutation
    description "Change a field's label, options, flags or data class. Options in use cannot be removed."
    permission "custom_field.manage"

    argument :id, ID, required: true
    argument :expected_version, Integer, required: false
    argument :label, String, required: false
    argument :description, String, required: false
    argument :options, [ Types::CustomFieldOptionInput ], required: false
    argument :data_class, String, required: false
    argument :required, Boolean, required: false
    argument :filterable, Boolean, required: false
    argument :display_order, Integer, required: false
    argument :show_on_apply, Boolean, required: false

    field :field, Types::CustomFieldDefinitionType, null: true

    def resolve(id:, expected_version: nil, options: nil, **changes)
      changes.delete(:show_on_apply) if changes[:show_on_apply].nil?
      changes[:options] = options.map(&:to_h) if options
      guarded do
        { field: CustomFieldDefinitions.update!(CustomField.find(id), changes, expected_version: expected_version), user_errors: [] }
      end
    end
  end
end
