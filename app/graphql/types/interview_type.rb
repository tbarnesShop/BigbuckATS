# frozen_string_literal: true

module Types
  class InterviewType < Types::BaseObject
    graphql_name "Interview"

    def self.authorized?(object, context)
      super && context[:principal]&.can?("application.read")
    end

    field :id, ID, null: false
    field :application_id, ID, null: false
    field :stage_key, String, null: false
    field :interview_key, String, null: false
    field :status, String, null: false
    field :starts_at, GraphQL::Types::ISO8601DateTime, null: true
    field :ends_at, GraphQL::Types::ISO8601DateTime, null: true
    field :interviewer_user_ids, [ ID ], null: false
    field :application, Types::ApplicationType, null: true

    def interviewer_user_ids = Array(object.interviewer_user_ids).map(&:to_s)
    def application = load_record(Application, object.application_id)
  end
end
