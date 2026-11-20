# frozen_string_literal: true

module Mutations
  class RecordConsent < ComplianceMutation
    description "Record a consent grant or withdrawal (a new row; consents are never edited)."
    permission "compliance.manage"

    argument :person_id, ID, required: true
    argument :purpose_key, String, required: true
    argument :status, String, required: true, description: "granted or withdrawn"

    field :consent, Types::ConsentType, null: true

    def resolve(person_id:, purpose_key:, status:)
      person = visible_person(person_id)
      return { consent: nil, user_errors: [ user_error("not_found", "Person not found") ] } unless person

      guarded(:consent) do
        consent = ComplianceDesk.record_consent!(person: person, purpose_key: purpose_key, status: status,
                                                 captured_via: Current.source_surface || "api")
        { consent: consent, user_errors: [] }
      end
    end
  end
end
