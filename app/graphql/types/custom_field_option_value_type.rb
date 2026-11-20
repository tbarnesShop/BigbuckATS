# frozen_string_literal: true

module Types
  class CustomFieldOptionValueType < Types::BaseObject
    graphql_name "CustomFieldOptionValue"
    implements Types::CustomFieldValueType

    field :option, String, null: true

    def option
      value = object.typed_value
      value
    end
  end
end
