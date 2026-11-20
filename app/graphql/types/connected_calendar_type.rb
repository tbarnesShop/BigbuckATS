# frozen_string_literal: true

module Types
  # Named ConnectedCalendar so GraphQL does not treat it as a Relay connection
  # (type names ending in Connection are connections).
  class ConnectedCalendarType < Types::BaseObject
    graphql_name "ConnectedCalendar"
    description "A connected or pending calendar. The grant (secret ref) is never returned."

    field :id, ID, null: false
    field :kind, String, null: false
    field :user_id, ID, null: true
    field :calendar_id, String, null: false
    field :status, String, null: false, description: "pending until a real grant exists, then connected"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
