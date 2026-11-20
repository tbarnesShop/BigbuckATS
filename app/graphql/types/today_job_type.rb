# frozen_string_literal: true

module Types
  class TodayJobType < Types::BaseObject
    graphql_name "TodayJob"

    field :id, ID, null: false
    field :title, String, null: false
    field :status, String, null: false
    field :openings, Integer, null: false
    field :active_count, Integer, null: false, description: "Active applications on this job"
  end
end
