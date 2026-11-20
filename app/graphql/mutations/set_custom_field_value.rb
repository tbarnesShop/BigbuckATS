# frozen_string_literal: true

module Mutations
  class SetCustomFieldValue < CustomFieldMutation
    description "Set or clear one custom field value on a record. Validated against the field's current definition."

    argument :entity_type, String, required: true, description: "person, job, application, offer, project or company"
    argument :entity_id, ID, required: true
    argument :key, String, required: true
    argument :value, Types::CustomFieldValueInput, required: true
    argument :expected_version, Integer, required: false, description: "The value's version you last read"

    field :value, Types::CustomFieldValueType, null: true

    def authorized?(entity_type:, **inputs)
      permission = CustomFieldValues::WRITE_PERMISSIONS[entity_type.to_s.underscore]
      if permission.nil? || !principal&.can?(permission)
        raise GraphQL::ExecutionError.new(
          "Setting #{entity_type} fields needs the #{permission || 'right'} permission.",
          extensions: { "code" => "insufficient_permission", "permission" => permission }.compact
        )
      end

      super
    end

    def resolve(entity_type:, entity_id:, key:, value:, expected_version: nil)
      guarded(:value) do
        if entity_type.to_s.underscore == "person"
          person = Person.find(entity_id)
          unless PersonVisibility.visible?(person, viewer: context[:viewer])
            next { value: nil, user_errors: [ user_error("not_found", "Person not found") ] }
          end
        end

        row = CustomFieldValues.write!(entity_type: entity_type, entity_id: entity_id, key: key,
                                       value: value.to_value, expected_version: expected_version)
        { value: CustomFieldTypes.present?(row, row.custom_field.field_type) ? row : nil, user_errors: [] }
      end
    end
  end
end
