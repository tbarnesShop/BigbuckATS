# frozen_string_literal: true

module Types
  class AgentType < Types::BaseObject
    graphql_name "Agent"

    # Your own agents, or everyone's with agent.manage.
    def self.authorized?(object, context)
      principal = context[:principal]
      super && principal && (principal.can?("agent.manage") || object.owner_membership_id == principal.membership&.id)
    end

    field :id, ID, null: false
    field :name, String, null: false
    field :description, String, null: true
    field :status, String, null: false
    field :scopes, [ String ], null: false
    field :owner_membership_id, ID, null: false
    field :version, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
