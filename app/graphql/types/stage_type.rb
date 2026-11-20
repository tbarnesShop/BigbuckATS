# frozen_string_literal: true

module Types
  class StageType < Types::BaseObject
    graphql_name "Stage"
    description "A stage in a resolved pipeline"

    field :key, String, null: false, hash_key: "key"
    field :name, String, null: true, hash_key: "name"
    field :type, String, null: true, hash_key: "type"
  end
end
