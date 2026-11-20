# frozen_string_literal: true

module Types
  class ConsentType < Types::BaseObject
    graphql_name "Consent"
    description "Consents are append-only; the newest row per purpose is current"

    field :id, ID, null: false
    field :purpose, String, null: true
    field :status, String, null: false
    field :lawful_basis, String, null: false
    field :captured_via, String, null: false
    field :captured_at, GraphQL::Types::ISO8601DateTime, null: false
    field :expires_at, GraphQL::Types::ISO8601DateTime, null: true
    field :granted, Boolean, null: false

    def purpose = load_record(ConsentPurpose, object.consent_purpose_id)&.key
    def granted = object.granted?
  end
end
