# frozen_string_literal: true

module V1
  class DncCompaniesController < ApplicationController
    before_action :require_tenant!

    rescue_from ActiveRecord::RecordInvalid do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_dnc", title: error.record.errors.full_messages.join(", "))
    end

    def index
      rows = DncCompany.includes(:company).order(:created_at).limit(200)
      render json: { data: rows.map { |r| serialize(r) } }
    end

    def create
      with_idempotency do
        row = DncCompany.create!(
          company_id: dnc_params[:company_id],
          domain: dnc_params[:domain]&.downcase,
          reason: dnc_params[:reason]
        )
        render json: serialize(row), status: :created
      end
    end

    def destroy
      DncCompany.find(params[:id]).destroy!
      head :no_content
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def dnc_params
      params.require(:dnc_company).permit(:company_id, :domain, :reason)
    end

    def serialize(row)
      row.as_json(only: %i[id organization_id company_id domain reason created_at]).merge(
        "company" => row.company&.as_json(only: %i[id name domain])
      )
    end
  end
end
