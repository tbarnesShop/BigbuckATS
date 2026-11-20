# frozen_string_literal: true

module V1
  class CompliancePoliciesController < ApplicationController
    before_action :require_tenant!

    def index
      rows = CompliancePolicy.order(priority: :desc, created_at: :asc).limit(100)
      render json: { data: rows.map { |p| serialize(p) } }
    end

    def show
      render json: serialize(CompliancePolicy.find(params[:id]))
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def serialize(policy)
      policy.as_json(
        only: %i[id organization_id key name priority is_fallback created_at updated_at]
      ).merge(
        "conditions" => policy.conditions,
        "requirements" => policy.requirements,
        "blocks" => policy.blocks_req
      )
    end
  end
end
