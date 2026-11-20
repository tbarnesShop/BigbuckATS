# frozen_string_literal: true

module Types
  # Who is calling. Drives the permission-aware nav in the web app.
  class ViewerType < Types::BaseObject
    graphql_name "Viewer"

    field :organization_id, ID, null: false
    field :actor_type, String, null: false, description: "user, agent or integration"
    field :user, Types::UserType, null: true, description: "The signed-in user, or the agent's owner"
    field :agent, Types::AgentType, null: true, description: "Set when an agent is acting"
    field :role_key, String, null: true
    field :permissions, [ String ], null: false
    field :api_version, String, null: false

    def role_key = object.membership&.role&.key
    def permissions = object.permissions.to_a.sort
  end
end
