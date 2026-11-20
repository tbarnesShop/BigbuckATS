# frozen_string_literal: true

module V1
  class TodayController < ApplicationController
    before_action :require_tenant!

    def show
      board = TodayBoard.call(
        actor_id: Current.actor_id,
        include_offers: permitted?("offer.read"),
        include_confidential_jobs: permitted?("job.read_confidential")
      )
      render json: {
        "feedback" => board.feedback.map { |row| serialize_interview(row) },
        "reviews" => board.reviews.map { |application| serialize_review(application) },
        "upcoming" => board.upcoming.map { |row| serialize_interview(row) },
        "offers_pending" => board.offers_pending.map { |offer| serialize_offer(offer) },
        "jobs" => board.jobs.map { |job| job.to_h.transform_keys(&:to_s) }
      }
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def serialize_interview(interview)
      interview.as_json(
        only: %i[id application_id stage_key interview_key status starts_at ends_at]
      ).merge("job_id" => interview.application&.job_id)
    end

    def serialize_review(application)
      {
        "application_id" => application.id,
        "job_id" => application.job_id,
        "stage_key" => application.current_stage_key,
        "applied_at" => application.created_at
      }
    end

    def serialize_offer(offer)
      {
        "id" => offer.id,
        "status" => offer.status,
        "application_id" => offer.application_id,
        "job_id" => offer.application&.job_id
      }
    end
  end
end
