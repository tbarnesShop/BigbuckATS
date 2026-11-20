# frozen_string_literal: true

module V1
  class ScorecardsController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_scorecard", title: error.message)
    end

    # Only the feedback the caller may read (see ScorecardVisibility): an interviewer does not get the
    # rest of the panel's scorecards for an interview until their own is submitted.
    def index
      rows = ScorecardVisibility.scope.includes(:interview, :user).order(:created_at)
      rows = rows.where(interview_id: params[:interview_id]) if params[:interview_id].present?
      if params[:application_id].present?
        interview_ids = Interview.where(application_id: params[:application_id]).select(:id)
        rows = rows.where(interview_id: interview_ids)
      end
      render json: { data: rows.limit(200).map { |s| serialize(s) } }
    end

    def create
      with_idempotency do
        interview = Interview.where(application_id: ResourceVisibility.applications.select(:id))
                             .find(scorecard_params.require(:interview_id))
        # Attribution stays with the signed-in actor. Seed and system paths call ScorecardSubmitter
        # directly when they need to write on behalf of each interviewer.
        if scorecard_params[:user_id].present? && scorecard_params[:user_id].to_s != Current.actor_id.to_s
          raise ArgumentError, "scorecard_not_own"
        end
        user = User.find(Current.actor_id)
        scorecard = ScorecardSubmitter.call(
          interview: interview,
          user: user,
          rating: scorecard_params.require(:rating),
          notes: scorecard_params[:notes],
          attribute_ratings: scorecard_params[:attribute_ratings]
        )
        render json: serialize(scorecard.reload), status: :created
      end
    end

    # Correct submitted feedback: the author changes their own; scorecard.manage changes anyone's.
    # The scorecard stays attributed to its author and the audit row records who edited it.
    def update
      with_idempotency do
        scorecard = ScorecardVisibility.scope.find(params[:id])
        raise Authorization::InsufficientPermission, "scorecard.manage" unless ScorecardVisibility.editable?(scorecard)

        ScorecardSubmitter.revise(
          scorecard: scorecard,
          rating: scorecard_params.require(:rating),
          notes: scorecard_params[:notes],
          attribute_ratings: scorecard_params[:attribute_ratings]
        )
        render json: serialize(scorecard.reload)
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def scorecard_params
      params.require(:scorecard).permit(:interview_id, :user_id, :rating, :notes, attribute_ratings: {})
    end

    def serialize(scorecard)
      scorecard.as_json(
        only: %i[id organization_id interview_id user_id status rating notes attribute_ratings created_at updated_at]
      ).merge(
        "interview" => scorecard.interview&.as_json(only: %i[id application_id interview_key status]),
        "user" => scorecard.user&.as_json(only: %i[id name email]),
        "can_edit" => ScorecardVisibility.editable?(scorecard)
      )
    end
  end
end
