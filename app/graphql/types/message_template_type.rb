# frozen_string_literal: true

module Types
  class MessageTemplateType < Types::BaseObject
    graphql_name "MessageTemplate"

    def self.authorized?(object, context)
      super && context[:principal]&.can?("sequence.read")
    end

    field :id, ID, null: false
    field :key, String, null: false
    field :message_type, String, null: false
    field :locale, String, null: false
    field :subject, String, null: false
    field :body, String, null: false
    field :archived_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
