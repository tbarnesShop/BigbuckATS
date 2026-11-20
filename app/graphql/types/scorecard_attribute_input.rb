# frozen_string_literal: true

module Types
  class ScorecardAttributeInput < Types::BaseInputObject
    graphql_name "ScorecardAttributeInput"

    argument :key, String, required: true
    argument :label, String, required: false
    argument :guidance, String, required: false
    argument :required, Boolean, required: false, description: "Defaults to required when omitted"
  end
end
