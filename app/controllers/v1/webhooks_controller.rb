# frozen_string_literal: true

module V1
  class WebhooksController < ApplicationController
    before_action :require_tenant!

    rescue_from WebhookUrl::Invalid do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_webhook_url", title: error.message)
    end

    def index
      rows = WebhookEndpoint.order(:created_at).limit(100)
      render json: { data: rows.map { |w| serialize(w) } }
    end

    def create
      with_idempotency do
        url = webhook_params.require(:url)
        WebhookUrl.validate!(url)
        endpoint = WebhookEndpoint.create!(
          key: webhook_params.require(:key),
          url: url,

          event_types: webhook_params[:event_types],
          active: true
        )
        render json: serialize(endpoint).merge("signing_secret" => endpoint.signing_secret), status: :created
      end
    end

    # Change the URL, the events it receives (empty = all), or turn it off and on.
    def update
      endpoint = WebhookEndpoint.find(params[:id])
      attrs = params.require(:webhook).permit(:url, :active, event_types: [])
      changes = {}
      if attrs[:url].present?
        WebhookUrl.validate!(attrs[:url])
        changes[:url] = attrs[:url]
      end
      changes[:event_types] = Array(attrs[:event_types]).reject(&:blank?).presence if params[:webhook].key?(:event_types)
      changes[:active] = ActiveModel::Type::Boolean.new.cast(attrs[:active]) if attrs.key?(:active)
      before = endpoint.attributes.slice(*changes.keys.map(&:to_s))
      endpoint.update!(changes)
      ChangeWriter.call(record: endpoint, action: "webhook.updated", event_type: "webhook.updated",
        payload: { "key" => endpoint.key }, changes: before.to_h { |key, value| [ key, [ value, endpoint[key] ] ] })
      render json: serialize(endpoint)
    end

    def rotate_secret
      endpoint = WebhookEndpoint.find(params[:id])
      secret = endpoint.rotate_signing_secret!
      render json: serialize(endpoint).merge("signing_secret" => secret)
    end

    def drain
      deliveries = WebhookDispatcher.drain!(organization_id: Current.organization_id)
      render json: {
        delivered: deliveries.count { |d| d.status == "delivered" },
        data: deliveries.map { |d| d.as_json(only: %i[id webhook_endpoint_id outbox_event_id event_type status attempt_count response_status next_attempt_at delivered_at]) }
      }
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def webhook_params
      params.require(:webhook).permit(:key, :url, event_types: [])
    end

    def serialize(endpoint)
      recent = WebhookDelivery.where(webhook_endpoint_id: endpoint.id).order(created_at: :desc).limit(10)
      endpoint.as_json(only: %i[id organization_id key url event_types active created_at]).merge(
        "recent_deliveries" => recent.map { |row|
          row.as_json(only: %i[id event_type status attempt_count response_status last_error delivered_at created_at])
        }
      )
    end
  end
end
