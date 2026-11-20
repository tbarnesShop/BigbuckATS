# frozen_string_literal: true

module V1
  class AffiliationsController < ApplicationController
    before_action :require_tenant!

    def index
      rows = PersonAffiliation.where(person_id: ResourceVisibility.people.select(:id)).includes(:company, :person).order(:created_at)
      rows = rows.where(person_id: params[:person_id]) if params[:person_id].present?
      rows = rows.where(company_id: params[:company_id]) if params[:company_id].present?
      render json: { data: rows.limit(200).map { |a| serialize(a) } }
    end

    def create
      with_idempotency do
        person = ResourceVisibility.people.find(affiliation_params.require(:person_id))
        company = Company.find(affiliation_params.require(:company_id))
        affiliation = PersonAffiliation.create!(
          person: person,
          company: company,
          title: affiliation_params[:title],
          current: ActiveModel::Type::Boolean.new.cast(affiliation_params[:current]) || false,
          started_on: affiliation_params[:started_on],
          ended_on: affiliation_params[:ended_on]
        )
        ChangeWriter.call(
          record: affiliation, action: "affiliation.created", event_type: "affiliation.created",
          payload: { "person_id" => person.id, "company_id" => company.id }
        )
        render json: serialize(affiliation), status: :created
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def affiliation_params
      params.require(:affiliation).permit(:person_id, :company_id, :title, :current, :started_on, :ended_on)
    end

    def serialize(affiliation)
      affiliation.as_json(
        only: %i[id organization_id person_id company_id title current started_on ended_on created_at]
      ).merge(
        "company" => affiliation.company&.as_json(only: %i[id name domain]),
        "person" => ResourceSummary.person(affiliation.person, fields: %i[id display_name])
      )
    end
  end
end
