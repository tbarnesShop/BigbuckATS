# frozen_string_literal: true

module Types
  class CustomFieldOptionsValueType < Types::BaseObject
    graphql_name "CustomFieldOptionsValue"
    implements Types::CustomFieldValueType

    field :options, [ String ], null: false

    def options
      value = object.typed_value
      Array(value)
    end
  end
end
