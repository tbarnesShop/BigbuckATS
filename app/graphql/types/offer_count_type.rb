# frozen_string_literal: true

module Types
  class OfferCountType < Types::BaseObject
    graphql_name "OfferCount"

    field :status, String, null: false, hash_key: "status"
    field :count, Integer, null: false, hash_key: "count"
  end
end
