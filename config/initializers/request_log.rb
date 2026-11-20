require "action_controller/log_subscriber"
# Rails' default subscriber logs paths and parameters before our allowlisted
# structured event. Disable it so arbitrary query/form/GraphQL values cannot leak.
Rails.application.config.after_initialize do
  ActionController::LogSubscriber.detach_from(:action_controller)
end

# frozen_string_literal: true

# One structured JSON line per API request: who acted (org, actor, agent,
# credential, surface), what ran, and how it went. Never request bodies or
# params, so no personal data reaches operational logs. Cloud Logging parses
# the JSON into fields, so requests can be filtered by actor or agent.
ActiveSupport::Notifications.subscribe("process_action.action_controller") do |event|
  payload = event.payload
  next if payload[:controller] == "Rails::HealthController"

  line = {
    event: "http.request",
    request_id: Current.request_id,
    organization_id: Current.organization_id,
    actor_type: Current.actor_type,
    actor_id: Current.audit_actor_id,
    on_behalf_of_id: Current.on_behalf_of_id,
    credential_id: Current.credential_id,
    surface: Current.source_surface,
    method: payload[:method],
    route: "#{payload[:controller]}##{payload[:action]}",
    status: payload[:status] || (payload[:exception] ? 500 : nil),
    duration_ms: event.duration.round(1),
    db_ms: payload[:db_runtime]&.round(1),
    error: payload[:exception]&.first
  }.compact

  Rails.logger.info(line.to_json)
end
