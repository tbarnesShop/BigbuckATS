# frozen_string_literal: true

module Types
  class DataRequestType < Types::BaseObject
    graphql_name "DataRequest"

    field :id, ID, null: false
    field :kind, String, null: false, description: "access, correction or erasure"
    field :status, String, null: false
    field :person_id, ID, null: true
    field :requester_email, String, null: true
    field :received_at, GraphQL::Types::ISO8601DateTime, null: false
    field :due_at, GraphQL::Types::ISO8601DateTime, null: false
    field :completed_at, GraphQL::Types::ISO8601DateTime, null: true
    field :outcome_note, String, null: true
  end
end
