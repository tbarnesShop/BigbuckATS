# frozen_string_literal: true

module Types
  class ScorecardRubricType < Types::BaseObject
    graphql_name "ScorecardRubric"

    field :id, ID, null: false
    field :key, String, null: false
    field :name, String, null: false
    field :guidance, String, null: true
    field :attributes_spec, GraphQL::Types::JSON, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
