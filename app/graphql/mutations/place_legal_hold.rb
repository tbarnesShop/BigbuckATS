# frozen_string_literal: true

module Mutations
  class PlaceLegalHold < ComplianceMutation
    description "Hold a person, application or job: retention and erasure skip held people."
    permission "compliance.manage"

    argument :subject_type, String, required: true
    argument :subject_id, ID, required: true
    argument :reason, String, required: true

    field :legal_hold, Types::LegalHoldType, null: true

    def resolve(subject_type:, subject_id:, reason:)
      guarded(:legal_hold) do
        { legal_hold: ComplianceDesk.place_hold!(subject_type: subject_type, subject_id: subject_id, reason: reason), user_errors: [] }
      end
    end
  end
end
