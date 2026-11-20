# frozen_string_literal: true

module Types
  class CustomFieldOptionInput < Types::BaseInputObject
    graphql_name "CustomFieldOptionInput"

    argument :key, String, required: true
    argument :label, String, required: false
  end
end
