# frozen_string_literal: true

module Types
  class OfferListType < Types::BaseObject
    graphql_name "OfferList"
    description "Offers for the hub, plus a status breakdown that ignores the status filter."

    field :counts, [ Types::OfferCountType ], null: false, hash_key: "counts"
    field :nodes, [ Types::OfferType ], null: false, hash_key: "nodes"
  end
end
