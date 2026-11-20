# frozen_string_literal: true

module Types
  class TodayType < Types::BaseObject
    graphql_name "Today"
    description "Recruiter home. Person and job names come from application.person and application.job."

    field :feedback, [ Types::InterviewType ], null: false, description: "Interviews I still owe a scorecard on"
    field :reviews, [ Types::ApplicationType ], null: false, description: "Active applications still on the first stage"
    field :upcoming, [ Types::InterviewType ], null: false, description: "Scheduled interviews in the next 7 days"
    field :offers_pending, [ Types::OfferType ], null: false, permission: "offer.read"
    # Application authorization rejects restricted people and confidential jobs.
    # Omit those rows before serializing this non-null list so one hidden record
    # cannot null the entire Today response.
    def reviews
      object.reviews.select { |application| Types::ApplicationType.authorized?(application, context) }
    end

    field :jobs, [ Types::TodayJobType ], null: false, permission: "job.read"
  end
end
