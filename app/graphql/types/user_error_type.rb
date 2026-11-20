# frozen_string_literal: true

module Types
  # A problem with the input the caller can fix. Mutations return these instead
  # of raising, so agents can read them and retry.
  class UserErrorType < Types::BaseObject
    graphql_name "UserError"

    field :code, String, null: false, description: "Stable machine-readable code, e.g. stale_version"
    field :message, String, null: false
    field :path, [ String ], null: true, description: "Which input field the error is about"
  end
end
