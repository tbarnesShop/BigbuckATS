# frozen_string_literal: true

module Types
  class PersonType < Types::BaseObject
    graphql_name "Person"

    # Same visibility rules as REST: role, scopes, restricted people and the
    # caller's dimension scopes. Hidden people resolve to null.
    def self.authorized?(object, context)
      super && PersonVisibility.visible?(object, viewer: context[:viewer])
    end

    field :id, ID, null: false
    field :display_name, String, null: false
    field :primary_email, String, null: true
    field :primary_phone, String, null: true
    field :lifecycle_stage, String, null: false
    field :visibility, String, null: false
    field :do_not_contact, Boolean, null: false
    field :version, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :applications, Types::ApplicationType.connection_type, null: false, permission: "application.read",
                                                                  description: "This person's applications, newest first"

    def applications
      Application.where(person_id: object.id).order(created_at: :desc)
    end

    field :custom_fields, [ Types::CustomFieldValueType ], null: false,
                                                        description: "Values of active custom fields you may see, in display order" do
      argument :keys, [ String ], required: false, description: "Only these field keys"
    end

    def custom_fields(keys: nil) = load_custom_fields("person", keys)

    field :consents, [ Types::ConsentType ], null: false, description: "Newest first"

    def consents = Consent.where(person_id: object.id).order(captured_at: :desc).to_a
  end
end
