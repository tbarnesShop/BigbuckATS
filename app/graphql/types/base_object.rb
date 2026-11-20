# frozen_string_literal: true

module Types
  class BaseObject < GraphQL::Schema::Object
    field_class Types::BaseField
    connection_type_class Types::BaseConnection
    edge_type_class Types::BaseEdge

    private

    def principal
      context[:principal]
    end

    # Membership-shaped viewer for PersonVisibility.
    def person_viewer
      context[:viewer]
    end

    def load_custom_fields(entity_type, keys)
      dataloader.with(Sources::CustomFieldValues, entity_type, keys&.sort, principal).load(object.id)
    end

    def load_record(model, id)
      return nil if id.blank?

      dataloader.with(Sources::RecordById, model).load(id)
    end
  end
end
