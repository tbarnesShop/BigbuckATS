# frozen_string_literal: true

module V1
  class ReferralsController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_referral", title: error.message)
    end

    def index
      rows = ResourceVisibility.referrals.includes(:person, :job).order(created_at: :desc).limit(100)
      rows = rows.where(job_id: params[:job_id]) if params[:job_id].present?
      rows = rows.where(referrer_user_id: params[:referrer_user_id]) if params[:referrer_user_id].present?
      render json: { data: rows.map { |r| serialize(r) } }
    end

    def create
      with_idempotency do
        referrer = User.find(Current.actor_id)
        job = ResourceVisibility.jobs.find_by(id: referral_params[:job_id]) if referral_params[:job_id].present?
        referral = ReferralCreator.call(
          referrer_user: referrer,
          display_name: referral_params.require(:display_name),
          email: referral_params[:email],
          job: job,
          note: referral_params[:note]
        )
        render json: serialize(referral.reload), status: :created
      end
    end

    def show
      render json: serialize(ResourceVisibility.referrals.includes(:person, :job).find(params[:id]))
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def referral_params
      params.require(:referral).permit(:display_name, :email, :job_id, :note)
    end

    def serialize(referral)
      referral.as_json(
        only: %i[id organization_id person_id referrer_user_id job_id application_id status note created_at]
      ).merge(
        "person" => ResourceSummary.person(referral.person, fields: %i[id display_name primary_email lifecycle_stage]),
        "job" => ResourceSummary.job(referral.job, fields: %i[id title status])
      )
    end
  end
end
