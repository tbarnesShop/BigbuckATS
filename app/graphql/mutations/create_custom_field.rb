# frozen_string_literal: true

module Mutations
  class CreateCustomField < CustomFieldMutation
    description "Add a custom field to a kind of record."
    permission "custom_field.manage"

    argument :entity, String, required: true
    argument :key, String, required: true, description: "lowercase, digits, _ or -; cannot change later"
    argument :label, String, required: true
    argument :field_type, String, required: true, description: CustomFieldTypes::ALL.join(", ")
    argument :data_class, String, required: false, default_value: "internal", description: "internal, pii or sensitive"
    argument :options, [ Types::CustomFieldOptionInput ], required: false
    argument :reference_type, String, required: false
    argument :description, String, required: false
    argument :required, Boolean, required: false, default_value: false
    argument :filterable, Boolean, required: false, default_value: false
    argument :display_order, Integer, required: false, default_value: 0
    argument :show_on_apply, Boolean, required: false, default_value: false,
                                      description: "Application fields only. Shown as a screening question."

    field :field, Types::CustomFieldDefinitionType, null: true

    def resolve(options: nil, **args)
      guarded { { field: CustomFieldDefinitions.create!(**args, options: options&.map(&:to_h)), user_errors: [] } }
    end
  end
end
