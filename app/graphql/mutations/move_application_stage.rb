# frozen_string_literal: true

module Mutations
  class MoveApplicationStage < BaseMutation
    description "Move an application to another stage of its pipeline. Stage guards apply."
    permission "application.move_stage"

    argument :application_id, ID, required: true
    argument :to_stage_key, String, required: true
    argument :reason, String, required: false
    argument :expected_version, Integer, required: false, description: "The version you last read; refused if it has changed"

    field :application, Types::ApplicationType, null: true

    def resolve(application_id:, to_stage_key:, reason: nil, expected_version: nil)
      Application.transaction do
        application, error = lock_with_version!(Application, application_id, expected_version)
        next { application: nil, user_errors: [ error ] } if error

        moved = SubjectTransitions.move(subject: application, to_stage_key: to_stage_key, reason: reason)
        { application: moved, user_errors: [] }
      end
    rescue ArgumentError, StageGuards::Error => e
      { application: nil, user_errors: [ user_error("invalid_transition", e.message, path: [ "toStageKey" ]) ] }
    end
  end
end
