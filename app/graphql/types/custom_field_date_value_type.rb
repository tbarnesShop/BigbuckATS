# frozen_string_literal: true

module Types
  class CustomFieldDateValueType < Types::BaseObject
    graphql_name "CustomFieldDateValue"
    implements Types::CustomFieldValueType

    field :date, GraphQL::Types::ISO8601Date, null: true

    def date
      value = object.typed_value
      value
    end
  end
end
