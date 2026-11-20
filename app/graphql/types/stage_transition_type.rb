# frozen_string_literal: true

module Types
  class StageTransitionType < Types::BaseObject
    graphql_name "StageTransition"

    field :id, ID, null: false
    field :from_stage_key, String, null: true
    field :to_stage_key, String, null: true
    field :command, String, null: false
    field :reason, String, null: true
    field :actor_id, ID, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
