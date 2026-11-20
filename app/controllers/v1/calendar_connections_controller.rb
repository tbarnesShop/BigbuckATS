# frozen_string_literal: true

module V1
  class CalendarConnectionsController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_calendar", title: error.message)
    end

    rescue_from GoogleSignIn::DomainNotVerified do |error|
      render_problem(status: :unprocessable_entity, code: "unverified_domain",
                     title: "Domain #{error.message} is not verified for this organization")
    end

    def index
      rows = CalendarConnection.order(:created_at).limit(100)
      render json: { data: rows.map { |row| serialize(row) } }
    end

    def create
      with_idempotency do
        connection = CalendarConnector.connect!(
          calendar_id: connection_params.require(:calendar_id),
          kind: connection_params[:kind],
          user_id: connection_params[:user_id],
          secret_ref: connection_params[:secret_ref],
          actor_id: Current.actor_id,
          allow_domain: permitted?("settings.manage"),
          allow_other_user: permitted?("settings.manage")
        )
        render json: serialize(connection), status: :created
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def connection_params
      params.require(:calendar_connection).permit(:kind, :user_id, :calendar_id, :secret_ref)
    end

    def serialize(row)
      row.as_json(only: %i[id kind user_id calendar_id status created_at])
    end
  end
end
