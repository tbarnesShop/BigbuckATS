# frozen_string_literal: true

module V1
  class SourcingTasksController < ApplicationController
    before_action :require_tenant!

    def index
      rows = SourcingTask.where(person_id: ResourceVisibility.people.select(:id)).includes(:person).order(created_at: :desc).limit(100)
      rows = rows.where(status: params[:status]) if params[:status].present?
      rows = rows.where(person_id: params[:person_id]) if params[:person_id].present?
      render json: { data: rows.map { |t| serialize(t) } }
    end

    def complete
      with_idempotency do
        task = SourcingTask.find(params[:id])
        task.complete!
        render json: serialize(task.reload)
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def serialize(task)
      task.as_json(
        only: %i[id organization_id person_id sequence_enrollment_id assignee_user_id title status due_at completed_at created_at]
      ).merge("person" => ResourceSummary.person(task.person, fields: %i[id display_name primary_email]))
    end
  end
end
