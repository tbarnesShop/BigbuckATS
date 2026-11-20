# frozen_string_literal: true

module Types
  class ApplicationFormType < Types::BaseObject
    graphql_name "ApplicationForm"

    field :required_fields, [ String ], null: false
    field :standard_fields, [ String ], null: false
    field :screening_questions, [ Types::ScreeningQuestionType ], null: false
  end
end
