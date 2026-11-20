# frozen_string_literal: true

module Types
  class CustomFieldTypeChangePreviewType < Types::BaseObject
    graphql_name "CustomFieldTypeChangePreview"
    description "Counts only; values are never returned"

    field :from_type, String, null: false, hash_key: "from_type"
    field :to_type, String, null: false, hash_key: "to_type"
    field :total, Integer, null: false, hash_key: "total"
    field :convertible, Integer, null: false, hash_key: "convertible"
    field :unconvertible, Integer, null: false, hash_key: "unconvertible"
    field :unconvertible_value_ids, [ ID ], null: false, hash_key: "unconvertible_value_ids"
  end
end
