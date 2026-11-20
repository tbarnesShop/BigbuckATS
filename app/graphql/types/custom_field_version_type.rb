# frozen_string_literal: true

module Types
  class CustomFieldVersionType < Types::BaseObject
    graphql_name "CustomFieldVersion"

    field :version, Integer, null: false
    field :change_kind, String, null: false
    field :definition, GraphQL::Types::JSON, null: false
    field :migration_summary, GraphQL::Types::JSON, null: true
    field :actor_id, ID, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
