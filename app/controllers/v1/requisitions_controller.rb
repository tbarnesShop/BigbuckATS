# frozen_string_literal: true

module V1
  class RequisitionsController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_requisition", title: error.message)
    end

    def index
      rows = Requisition.order(:created_at).limit(100)
      rows = rows.where(status: params[:status]) if params[:status].present?
      render json: { data: rows.map { |r| serialize(r) } }
    end

    def show
      render json: serialize(Requisition.find(params[:id]))
    end

    def create
      with_idempotency do
        req = Requisition.create!(
          code: requisition_params.require(:code),
          title: requisition_params.require(:title),
          employment_type: requisition_params[:employment_type],
          headcount: requisition_params[:headcount].presence || 1,
          status: "draft",
          owner_user_id: requisition_params[:owner_user_id].presence || Current.actor_id
        )
        ChangeWriter.call(
          record: req, action: "requisition.created", event_type: "requisition.created",
          payload: { "code" => req.code, "title" => req.title, "headcount" => req.headcount }
        )
        render json: serialize(req), status: :created
      end
    end

    def open_req
      with_idempotency do
        req = Requisition.find(params[:id])
        raise ArgumentError, "already_closed" if req.status == "closed"
        req.open!
        ChangeWriter.call(
          record: req, action: "requisition.opened", event_type: "requisition.opened",
          payload: { "status" => req.status }
        )
        render json: serialize(req.reload)
      end
    end

    def close
      with_idempotency do
        req = Requisition.find(params[:id])
        req.close!
        ChangeWriter.call(
          record: req, action: "requisition.closed", event_type: "requisition.closed",
          payload: { "status" => req.status }
        )
        render json: serialize(req.reload)
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def requisition_params
      params.require(:requisition).permit(:code, :title, :employment_type, :headcount, :owner_user_id)
    end

    def serialize(req)
      filled = req.filled_count
      req.as_json(
        only: %i[id organization_id code title employment_type headcount status owner_user_id approved_at closed_at created_at updated_at]
      ).merge(
        "filled_count" => filled,
        "openings_remaining" => [ req.headcount - filled, 0 ].max,
        "jobs" => req.jobs.map { |j| j.as_json(only: %i[id title status]) }
      )
    end
  end
end
