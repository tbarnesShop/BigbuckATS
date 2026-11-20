# frozen_string_literal: true

module V1
  class EnrollmentsController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_enrollment", title: error.message)
    end

    def index
      rows = SequenceEnrollment.where(person_id: ResourceVisibility.people.select(:id)).includes(:person, :mailbox, :sequence).order(:created_at)
      rows = rows.where(person_id: params[:person_id]) if params[:person_id].present?
      rows = rows.where(status: params[:status]) if params[:status].present?
      render json: { data: rows.limit(200).map { |e| serialize(e) } }
    end

    def show
      render json: serialize(SequenceEnrollment.where(person_id: ResourceVisibility.people.select(:id)).includes(:person, :mailbox, :sequence).find(params[:id]))
    end

    def stop
      with_idempotency do
        enrollment = SequenceEnrollment.find(params[:id])
        raise ArgumentError, "not_active" unless enrollment.active?

        enrollment.stop!(params[:reason].presence || "manual")
        render json: serialize(enrollment.reload)
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def serialize(enrollment)
      enrollment.as_json(
        only: %i[id organization_id sequence_id person_id mailbox_id step_index status stop_reason created_at updated_at]
      ).merge(
        "person" => ResourceSummary.person(enrollment.person, fields: %i[id display_name primary_email]),
        "sequence" => enrollment.sequence&.as_json(only: %i[id key name]),
        "mailbox" => enrollment.mailbox&.as_json(only: %i[id email kind])
      )
    end
  end
end
