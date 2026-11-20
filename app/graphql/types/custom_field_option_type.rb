# frozen_string_literal: true

module Types
  class CustomFieldOptionType < Types::BaseObject
    graphql_name "CustomFieldOption"

    field :key, String, null: false, hash_key: "key"
    field :label, String, null: false, hash_key: "label"
  end
end
