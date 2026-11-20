# frozen_string_literal: true

module Types
  class LegalHoldType < Types::BaseObject
    graphql_name "LegalHold"

    field :id, ID, null: false
    field :subject_type, String, null: false
    field :subject_id, ID, null: false
    field :reason, String, null: false
    field :placed_by_user_id, ID, null: false
    field :placed_at, GraphQL::Types::ISO8601DateTime, null: false
    field :released_at, GraphQL::Types::ISO8601DateTime, null: true
    field :active, Boolean, null: false

    def active = object.active?
  end
end
