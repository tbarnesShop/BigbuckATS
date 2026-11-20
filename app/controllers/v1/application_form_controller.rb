# frozen_string_literal: true

module V1
  # Which standard fields the public careers application form requires.
  # Stored in the organization's settings; screening questions are custom
  # fields flagged `show_on_apply`.
  class ApplicationFormController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_application_form", title: error.message)
    end

    def show
      render json: ApplicationFormSettings.as_json(form_for(Organization.find(Current.organization_id)))
    end

    def update
      org = Organization.find(Current.organization_id)
      fields = form_params[:required_fields]
      raise ArgumentError, "required_fields_missing" if fields.nil?

      ApplicationFormSettings.update!(
        org,
        required_fields: fields,
        screening_field_ids: screening_field_ids
      )
      render json: ApplicationFormSettings.as_json(form_for(org.reload))
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def form_params
      params.fetch(:application_form, {}).permit(required_fields: [], screening_field_ids: [])
    end

    # Omitted or JSON null leaves screening flags alone. [] clears them.
    def screening_field_ids
      raw = params[:application_form]
      return nil unless raw.respond_to?(:key?) && raw.key?(:screening_field_ids)
      return nil if raw[:screening_field_ids].nil?

      form_params[:screening_field_ids]
    end

    def form_for(org)
      ApplicationFormSettings.payload(org, principal: current_principal.is_a?(Principal) ? current_principal : nil)
    end
  end
end
