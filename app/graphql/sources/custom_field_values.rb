# frozen_string_literal: true

module Sources
  # Loads custom field values for many records of one entity type in one query.
  class CustomFieldValues < GraphQL::Dataloader::Source
    def initialize(entity_type, keys, principal)
      @entity_type = entity_type
      @keys = keys
      @principal = principal
    end

    def fetch(entity_ids)
      by_entity = ::CustomFieldValues.for_entities(entity_type: @entity_type, entity_ids: entity_ids.uniq,
                                                   keys: @keys, principal: @principal)
      entity_ids.map { |id| by_entity[id] || [] }
    end
  end
end
