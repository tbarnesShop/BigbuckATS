# frozen_string_literal: true

module V1
  class SavedSearchesController < ApplicationController
    include PersonScoped

    before_action :require_tenant!

    def index
      rows = SavedSearch.where(user_id: actor_user_id).order(:name)
      render json: { data: rows.map { |s| serialize(s) } }
    end

    def create
      with_idempotency do
        search = SavedSearch.create!(
          user_id: actor_user_id,
          name: params.require(:saved_search).require(:name),
          entity_type: params.dig(:saved_search, :entity_type).presence || "person",
          filters: PersonSearch.permitted_filters(params.require(:saved_search).require(:filters))
        )
        render json: serialize(search), status: :created
      end
    end

    def update
      with_idempotency do
        search = SavedSearch.where(user_id: actor_user_id).find(params[:id])
        attrs = params.require(:saved_search)
        search.name = attrs[:name] if attrs.key?(:name)
        search.filters = attrs[:filters] if attrs.key?(:filters)
        search.save!
        render json: serialize(search)
      end
    end

    # Runs the saved filters now: GET /saved_searches/:id/people
    def people
      search = SavedSearch.where(user_id: actor_user_id).find(params[:id])
      limit = [ [ (params[:limit] || 100).to_i, 1 ].max, 500 ].min
      filters = search.filters.to_h
      rows = PersonSearch.call(viewer: viewer, filters: filters, limit: limit)
      render json: {
        data: rows.map { |p| p.as_json(only: %i[id display_name primary_email current_title headline city engagement_status source last_contacted_at]) },
        meta: { "total" => PersonSearch.count(viewer: viewer, filters: filters) }
      }
    end

    def destroy
      search = SavedSearch.where(user_id: actor_user_id).find(params[:id])
      search.destroy!
      head :no_content
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def actor_user_id
      Current.actor_id.presence || raise(ArgumentError, "actor_required")
    end

    def serialize(search)
      search.as_json(only: %i[id organization_id user_id name entity_type filters created_at updated_at])
    end
  end
end
