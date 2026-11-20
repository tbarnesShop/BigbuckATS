# frozen_string_literal: true

module Types
  # Exactly one member: the typed value to store, or clear: true.
  class CustomFieldValueInput < Types::BaseInputObject
    graphql_name "CustomFieldValueInput"
    one_of

    argument :text, String, required: false
    argument :number, Float, required: false
    argument :date, GraphQL::Types::ISO8601Date, required: false
    argument :boolean, Boolean, required: false
    argument :option, String, required: false
    argument :options, [ String ], required: false
    argument :reference_id, ID, required: false
    argument :clear, Boolean, required: false

    def to_value
      h = to_h
      return nil if h[:clear]

      h.values.compact.first
    end
  end
end
