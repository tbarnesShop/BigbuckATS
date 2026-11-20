# frozen_string_literal: true

module Types
  # One stored custom field value. Implementations carry the typed value, so
  # every organization shares one schema however its fields are configured.
  module CustomFieldValueType
    include Types::BaseInterface
    graphql_name "CustomFieldValue"

    field :key, String, null: false
    field :field_type, String, null: false
    field :field_version, Integer, null: false, description: "The definition version this value was written under"
    field :version, Integer, null: false, description: "Pass as expectedVersion when setting this value"
    field :definition, Types::CustomFieldDefinitionType, null: false

    def key = object.custom_field.key
    def field_type = object.custom_field.field_type
    def definition = object.custom_field

    definition_methods do
      def resolve_type(object, _context)
        case CustomFieldTypes.canonical(object.custom_field.field_type)
        when "number", "currency" then Types::CustomFieldNumberValueType
        when "date" then Types::CustomFieldDateValueType
        when "boolean" then Types::CustomFieldBooleanValueType
        when "select" then Types::CustomFieldOptionValueType
        when "multi_select" then Types::CustomFieldOptionsValueType
        when "reference" then Types::CustomFieldReferenceValueType
        else Types::CustomFieldTextValueType
        end
      end
    end
  end
end
