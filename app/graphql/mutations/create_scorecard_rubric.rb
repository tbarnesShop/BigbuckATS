# frozen_string_literal: true

module Mutations
  class CreateScorecardRubric < BaseMutation
    description "Add a scorecard rubric. Interview definitions reference it with rubric_key."
    permission "settings.manage"

    argument :key, String, required: true
    argument :name, String, required: true
    argument :guidance, String, required: false
    argument :attributes, [ Types::ScorecardAttributeInput ], required: true

    field :rubric, Types::ScorecardRubricType, null: true

    def resolve(key:, name:, attributes:, guidance: nil)
      rubric = ScorecardRubricWriter.create!(
        key: key, name: name, guidance: guidance, attributes_spec: attributes.map(&:to_h)
      )
      { rubric: rubric, user_errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      { rubric: nil, user_errors: [ user_error("validation_failed", e.record.errors.full_messages.join(", ")) ] }
    end
  end
end
