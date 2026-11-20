# frozen_string_literal: true

module V1
  class MessageTemplatesController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_message_template", title: error.message)
    end

    STATUSES = MessageTemplate::STATUSES

    def index
      status = params[:status].presence || "active"
      raise ArgumentError, "unknown_status:#{status}" unless STATUSES.include?(status)

      rows = MessageTemplate.order(:key, :locale)
      rows = rows.active if status == "active"
      rows = rows.archived if status == "archived"
      render json: { data: rows.limit(200).map { |row| serialize(row) } }
    end

    def create
      with_idempotency do
        attrs = template_params
        template = MessageTemplate.create_template!(
          key: attrs[:key], message_type: attrs[:message_type], subject: attrs[:subject],
          body: attrs[:body], locale: attrs[:locale]
        )
        render json: serialize(template), status: :created
      end
    end

    def update
      template = MessageTemplate.find(params[:id])
      attrs = params.require(:message_template).permit(:subject, :body, :message_type)
      template.update_template!(subject: attrs[:subject].presence || template.subject,
        body: attrs[:body].presence || template.body, message_type: attrs[:message_type])
      render json: serialize(template)
    end

    def archive
      with_idempotency do
        template = MessageTemplate.find(params[:id])
        template.archive_template!
        render json: serialize(template)
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def template_params
      params.require(:message_template).permit(:key, :message_type, :locale, :subject, :body)
    end

    def serialize(template)
      template.as_json(
        only: %i[id organization_id key message_type locale subject body archived_at created_at updated_at]
      )
    end
  end
end
