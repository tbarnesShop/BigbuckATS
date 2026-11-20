# frozen_string_literal: true

module Mutations
  class CompleteDataRequest < ComplianceMutation
    description "Fulfil a request: access returns the access packet; erasure erases the person (legal holds refuse)."
    permission "compliance.manage"

    argument :id, ID, required: true
    argument :outcome_note, String, required: false
    argument :erase_mode, String, required: false, default_value: "delete", description: "delete or anonymize"

    field :data_request, Types::DataRequestType, null: true
    field :result, GraphQL::Types::JSON, null: true, description: "The access packet, or the erasure check"

    def resolve(id:, erase_mode:, outcome_note: nil)
      request = DataRequest.find(id)
      needed = ComplianceDesk.fulfil_permission(request)
      unless principal.can?(needed)
        return { data_request: nil, result: nil, user_errors: [ user_error("insufficient_permission", "Needs #{needed}") ] }
      end

      guarded(:data_request) do
        completed, result = ComplianceDesk.complete_request!(request, outcome_note: outcome_note, erase_mode: erase_mode)
        { data_request: completed, result: result, user_errors: [] }
      end
    end
  end
end
