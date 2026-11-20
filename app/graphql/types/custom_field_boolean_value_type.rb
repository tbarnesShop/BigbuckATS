# frozen_string_literal: true

module Types
  class CustomFieldBooleanValueType < Types::BaseObject
    graphql_name "CustomFieldBooleanValue"
    implements Types::CustomFieldValueType

    field :boolean, Boolean, null: true

    def boolean
      value = object.typed_value
      value
    end
  end
end
