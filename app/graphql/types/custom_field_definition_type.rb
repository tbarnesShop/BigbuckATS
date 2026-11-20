# frozen_string_literal: true

module Types
  class CustomFieldDefinitionType < Types::BaseObject
    graphql_name "CustomFieldDefinition"
    description "A versioned custom field definition. Archived, never deleted."

    field :id, ID, null: false
    field :entity, String, null: false
    field :key, String, null: false
    field :label, String, null: false
    field :description, String, null: true
    field :field_type, String, null: false
    field :data_class, String, null: false
    field :options, [ Types::CustomFieldOptionType ], null: false
    field :reference_type, String, null: true
    field :required, Boolean, null: false
    field :filterable, Boolean, null: false
    field :display_order, Integer, null: false
    field :show_on_apply, Boolean, null: false, description: "Application fields only: ask this on the public careers form"
    field :status, String, null: false
    field :version, Integer, null: false, description: "Pass as expectedVersion when changing the definition"
    field :versions, [ Types::CustomFieldVersionType ], null: false, permission: "custom_field.manage"

    def options = Array(object.options).map { |o| o.is_a?(Hash) ? o.stringify_keys : { "key" => o.to_s, "label" => o.to_s } }
    def versions = object.versions.to_a
  end
end
