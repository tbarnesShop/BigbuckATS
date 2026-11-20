# frozen_string_literal: true

module Types
  class ScreeningQuestionType < Types::BaseObject
    graphql_name "ScreeningQuestion"

    field :id, ID, null: false
    field :key, String, null: false
    field :label, String, null: false
    field :field_type, String, null: false
    field :required, Boolean, null: false
    field :options, [ Types::CustomFieldOptionType ], null: false

    def options
      Array(object.options).map { |option| option.is_a?(Hash) ? option.stringify_keys : { "key" => option.to_s, "label" => option.to_s } }
    end
  end
end
