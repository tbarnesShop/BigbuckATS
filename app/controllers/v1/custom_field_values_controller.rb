# frozen_string_literal: true

module V1
  # PUT /v1/custom_field_values { entity_type, entity_id, key, value, expected_version? }
  class CustomFieldValuesController < ApplicationController
    rescue_from CustomFieldDefinitions::Error do |error|
      status = error.code == "stale_version" ? :conflict : :unprocessable_entity
      render_problem(status: status, code: error.code, title: error.message)
    end

    def upsert
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?

      entity = CustomFieldValues.entity_name(params.require(:entity_type))
      require_permission!(CustomFieldValues::WRITE_PERMISSIONS.fetch(entity))
      if entity == "person" && current_principal
        person = Person.find(params.require(:entity_id))
        raise ActiveRecord::RecordNotFound unless PersonVisibility.visible?(person, viewer: PrincipalViewer.new(current_principal))
      end

      row = CustomFieldValues.write!(
        entity_type: entity, entity_id: params.require(:entity_id), key: params.require(:key),
        value: params[:value].respond_to?(:to_unsafe_h) ? params[:value].to_unsafe_h : params[:value],
        expected_version: params[:expected_version]&.to_i
      )
      render json: {
        "id" => row.id, "key" => row.custom_field.key, "entity_type" => row.entity_type, "entity_id" => row.entity_id,
        "value" => row.typed_value, "field_version" => row.field_version, "version" => row.version
      }
    end
  end
end
