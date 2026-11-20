# frozen_string_literal: true

module Mutations
  class RejectApplication < BaseMutation
    description "Reject an active application with a reason."
    permission "application.move_stage"

    argument :application_id, ID, required: true
    argument :reason, String, required: true
    argument :expected_version, Integer, required: false

    field :application, Types::ApplicationType, null: true

    def resolve(application_id:, reason:, expected_version: nil)
      Application.transaction do
        application, error = lock_with_version!(Application, application_id, expected_version)
        next { application: nil, user_errors: [ error ] } if error
        unless application.status == "active"
          next { application: nil, user_errors: [ user_error("not_active", "Only active applications can be rejected.") ] }
        end

        { application: SubjectTransitions.reject(subject: application, reason: reason), user_errors: [] }
      end
    rescue ArgumentError, StageGuards::Error => e
      { application: nil, user_errors: [ user_error("invalid_transition", e.message) ] }
    end
  end
end
