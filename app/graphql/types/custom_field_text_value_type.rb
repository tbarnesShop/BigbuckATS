# frozen_string_literal: true

module Types
  class CustomFieldTextValueType < Types::BaseObject
    graphql_name "CustomFieldTextValue"
    implements Types::CustomFieldValueType

    field :text, String, null: true

    def text
      value = object.typed_value
      value
    end
  end
end
