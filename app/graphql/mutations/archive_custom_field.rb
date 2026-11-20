# frozen_string_literal: true

module Mutations
  class ArchiveCustomField < CustomFieldMutation
    description "Archive a field. Its values are kept and it can be restored."
    permission "custom_field.manage"

    argument :id, ID, required: true
    argument :expected_version, Integer, required: false
    argument :restore, Boolean, required: false, default_value: false, description: "true restores an archived field"

    field :field, Types::CustomFieldDefinitionType, null: true

    def resolve(id:, restore:, expected_version: nil)
      field = CustomField.find(id)
      guarded do
        result = if restore
                   CustomFieldDefinitions.restore!(field, expected_version: expected_version)
        else
                   CustomFieldDefinitions.archive!(field, expected_version: expected_version)
        end
        { field: result, user_errors: [] }
      end
    end
  end
end
