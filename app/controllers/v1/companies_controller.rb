# frozen_string_literal: true

module V1
  class CompaniesController < ApplicationController
    before_action :require_tenant!

    def index
      rows = Company.includes(:affiliations).order(:name).limit(100)
      render json: { data: rows.map { |c| serialize(c) } }
    end

    def show
      render json: serialize(Company.includes(:affiliations).find(params[:id]))
    end

    def create
      with_idempotency do
        company = Company.create!(
          name: company_params.require(:name),
          domain: company_params[:domain],
          industry: company_params[:industry],
          employee_band: company_params[:employee_band]
        )
        ChangeWriter.call(
          record: company, action: "company.created", event_type: "company.created",
          payload: { "name" => company.name }
        )
        render json: serialize(company), status: :created
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def company_params
      params.require(:company).permit(:name, :domain, :industry, :employee_band)
    end

    def serialize(company)
      affiliations = company.affiliations.to_a
      company.as_json(only: %i[id organization_id name normalized_name domain industry employee_band created_at updated_at])
             .merge(
               "affiliation_count" => affiliations.size,
               "current_count" => affiliations.count(&:current),
               "former_count" => affiliations.count { |row| !row.current }
             )
    end
  end
end
