# frozen_string_literal: true

module V1
  # Versioned custom field definitions (GraphQL has the same commands).
  class CustomFieldsController < ApplicationController
    before_action :require_tenant!

    rescue_from CustomFieldDefinitions::Error do |error|
      status = error.code == "stale_version" ? :conflict : :unprocessable_entity
      render_problem(status: status, code: error.code, title: error.message)
    end

    def index
      scope = CustomField.order(:entity, :display_order, :key)
      scope = scope.where(entity: params[:entity]) if params[:entity].present?
      scope = scope.where(status: "active") unless ActiveModel::Type::Boolean.new.cast(params[:include_archived])
      render json: { data: scope.map { |f| serialize(f) } }
    end

    def show
      field = CustomField.find(params[:id])
      render json: serialize(field).merge("versions" => field.versions.map { |v| v.as_json(only: %i[version change_kind definition migration_summary actor_id created_at]) })
    end

    def create
      with_idempotency do
        attrs = field_attributes.symbolize_keys
        field = CustomFieldDefinitions.create!(**attrs.slice(:entity, :key, :label, :field_type, :data_class, :options,
                                                              :description, :reference_type, :required, :filterable,
                                                              :display_order, :visibility_roles, :show_on_apply))
        render json: serialize(field), status: :created
      end
    end

    def update
      field = CustomFieldDefinitions.update!(
        CustomField.find(params[:id]),
        field_attributes.slice(*CustomFieldDefinitions::EDITABLE),
        expected_version: params[:expected_version]&.to_i
      )
      render json: serialize(field)
    end

    def archive
      render json: serialize(CustomFieldDefinitions.archive!(CustomField.find(params[:id]), expected_version: params[:expected_version]&.to_i))
    end

    def restore
      render json: serialize(CustomFieldDefinitions.restore!(CustomField.find(params[:id]), expected_version: params[:expected_version]&.to_i))
    end

    # POST /v1/custom_fields/:id/type_change { to_type, options?, on_unconvertible?, dry_run? }
    def type_change
      field = CustomField.find(params[:id])
      options = params[:options]&.map { |o| o.respond_to?(:permit) ? o.permit(:key, :label).to_h : o }
      if ActiveModel::Type::Boolean.new.cast(params[:dry_run])
        return render json: CustomFieldDefinitions.preview_type_change(field, to_type: params.require(:to_type), options: options,
                                                                              reference_type: params[:reference_type])
      end

      changed = CustomFieldDefinitions.change_type!(
        field, to_type: params.require(:to_type), options: options, reference_type: params[:reference_type],
               on_unconvertible: params[:on_unconvertible].presence || "refuse", expected_version: params[:expected_version]&.to_i
      )
      render json: serialize(changed)
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def field_params
      params.require(:custom_field).permit(:entity, :key, :label, :field_type, :data_class, :description, :reference_type,
                                           :required, :filterable, :display_order, :show_on_apply, visibility_roles: [],
                                           options: %i[key label])
    end

    def field_attributes
      attrs = field_params.to_h
      if attrs.key?("show_on_apply")
        attrs["show_on_apply"] = ActiveModel::Type::Boolean.new.cast(attrs["show_on_apply"])
      end
      attrs
    end

    def serialize(field)
      field.as_json(only: %i[id entity key label description field_type data_class options reference_type required
                             filterable display_order show_on_apply visibility_roles status version archived_at created_at updated_at])
    end
  end
end
