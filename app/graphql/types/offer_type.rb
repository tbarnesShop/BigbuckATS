# frozen_string_literal: true

module Types
  class OfferType < Types::BaseObject
    graphql_name "Offer"
    description "An offer without compensation fields. Those need offer.view_compensation and stay on the offer record read."

    def self.authorized?(object, context)
      super && context[:principal]&.can?("offer.read")
    end

    field :id, ID, null: false
    field :application_id, ID, null: false
    field :status, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :application, Types::ApplicationType, null: true

    def application = load_record(Application, object.application_id)
  end
end
