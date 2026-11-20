# frozen_string_literal: true

module Mutations
  class ReleaseLegalHold < ComplianceMutation
    permission "compliance.manage"

    argument :id, ID, required: true

    field :legal_hold, Types::LegalHoldType, null: true

    def resolve(id:)
      guarded(:legal_hold) { { legal_hold: ComplianceDesk.release_hold!(LegalHold.find(id)), user_errors: [] } }
    end
  end
end
