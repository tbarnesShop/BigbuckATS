# frozen_string_literal: true

module V1
  class EventsController < ApplicationController
    before_action :require_tenant!

    def index
      rows = OutboxEvent.order(created_at: :desc).limit((params[:limit] || 50).to_i.clamp(1, 200))
      rows = rows.where(event_type: params[:event_type]) if params[:event_type].present?
      render json: {
        data: rows.map { |e|
          e.as_json(only: %i[id event_type resource_type resource_id subject_version delivered_at created_at])
           .merge("payload" => e.payload)
        }
      }
    end

    def sync_people
      page = SyncFeed.people(since_token: params[:sync_token], limit: (params[:limit] || 100).to_i.clamp(1, 200))
      render json: page
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end
  end
end
