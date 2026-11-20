# frozen_string_literal: true

module Types
  class CustomFieldNumberValueType < Types::BaseObject
    graphql_name "CustomFieldNumberValue"
    implements Types::CustomFieldValueType

    field :number, Float, null: true

    def number
      value = object.typed_value
      value&.to_f
    end
  end
end
