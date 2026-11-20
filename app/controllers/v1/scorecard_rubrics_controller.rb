# frozen_string_literal: true

module V1
  class ScorecardRubricsController < ApplicationController
    before_action :require_tenant!

    def index
      rows = ScorecardRubric.order(:key).limit(100)
      render json: { data: rows.map { |row| serialize(row) } }
    end

    def create
      with_idempotency do
        rubric = ScorecardRubricWriter.create!(
          key: rubric_params.require(:key),
          name: rubric_params.require(:name),
          guidance: rubric_params[:guidance],
          attributes_spec: rubric_params[:attributes_spec]
        )
        render json: serialize(rubric), status: :created
      end
    end

    def update
      with_idempotency do
        rubric = ScorecardRubric.find(params[:id])
        attrs = params.require(:scorecard_rubric).permit(:name, :guidance, attributes_spec: %i[key label guidance required])
        ScorecardRubricWriter.update!(
          rubric: rubric,
          name: attrs[:name],
          guidance: attrs.key?(:guidance) ? attrs[:guidance] : :unchanged,
          attributes_spec: attrs.key?(:attributes_spec) ? attrs[:attributes_spec] : nil
        )
        render json: serialize(rubric.reload)
      rescue ActiveRecord::RecordInvalid => e
        render_problem(status: :unprocessable_entity, code: "invalid_rubric", title: e.record.errors.full_messages.to_sentence)
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def rubric_params
      params.require(:scorecard_rubric).permit(:key, :name, :guidance, attributes_spec: %i[key label guidance required])
    end

    def serialize(rubric)
      rubric.as_json(only: %i[id key name guidance attributes_spec created_at updated_at])
    end
  end
end
