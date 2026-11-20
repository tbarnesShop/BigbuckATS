# frozen_string_literal: true

module Mutations
  class OpenDataRequest < ComplianceMutation
    description "Log a data-subject request (access, correction or erasure). The due date follows the person's compliance policy."
    permission "compliance.manage"

    argument :kind, String, required: true
    argument :requester_email, String, required: true
    argument :person_id, ID, required: false
    argument :due_at, GraphQL::Types::ISO8601DateTime, required: false

    field :data_request, Types::DataRequestType, null: true

    def resolve(kind:, requester_email:, person_id: nil, due_at: nil)
      guarded(:data_request) do
        person = person_id && visible_person(person_id)
        next { data_request: nil, user_errors: [ user_error("not_found", "Person not found", path: [ "personId" ]) ] } if person_id && !person

        request = ComplianceDesk.open_request!(kind: kind, requester_email: requester_email, person: person, due_at: due_at)
        { data_request: request, user_errors: [] }
      end
    end
  end
end
