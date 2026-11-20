# frozen_string_literal: true

module V1
  class ConfigController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_config", title: error.message)
    end
    rescue_from ConfigPlanner::Conflict do |error|
      render_problem(status: :conflict, code: "config_conflict", title: error.message)
    end
    rescue_from ConfigExecutors::Invalid do |error|
      render_problem(status: :unprocessable_entity, code: "config_invalid", title: error.message, param: error.identity)
    end

    rescue_from ConfigApplier::ObjectChanged do |error|
      render_problem(status: :conflict, code: "config_object_changed", title: error.message)
    end

    def plan
      with_idempotency do
        documents = Array(params.require(:documents)).map { |d| d.respond_to?(:to_unsafe_h) ? d.to_unsafe_h : d.to_h }
        plan = ConfigPlanner.plan(documents: documents)
        render json: serialize_plan(plan), status: :created
      end
    end

    def apply
      with_idempotency do
        plan = ConfigPlan.find(params.require(:plan_id))
        result = ConfigApplier.apply!(plan)
        render json: {
          "plan" => serialize_plan(plan.reload),
          "applied" => result
        }
      end
    end

    def plans
      rows = ConfigPlan.order(created_at: :desc).limit(50)
      render json: { data: rows.map { |p| serialize_plan(p) } }
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def serialize_plan(plan)
      plan.as_json(only: %i[id status manifest_hash created_at updated_at])
          .merge(
            "change_set" => plan.change_set,
            "desired_manifest" => plan.desired_manifest
          )
    end
  end
end
