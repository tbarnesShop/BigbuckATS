# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ProblemResponses
  include IdempotentRequest
  include Authorization
  include DemoContext

  SURFACES = %w[web api cli mcp agent import automation config system].freeze

  before_action :assign_request_context
  around_action :with_demo_context
  before_action :authorize_action!
  rate_limit to: 300, within: 1.minute, by: -> { request.remote_ip }, name: "api-ip"
  after_action do
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "no-referrer"
  end

  rescue_from Current::TenantRequired do |error|
    render_problem(status: :unauthorized, code: "tenant_required", title: error.message)
  end

  rescue_from ActiveRecord::RecordNotFound do
    render_problem(status: :not_found, code: "not_found", title: "Resource not found")
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_problem(
      status: :unprocessable_entity,
      code: "validation_failed",
      title: "Validation failed",
      detail: error.record.errors.full_messages.join(", ")
    )
  end

  rescue_from Authorization::InsufficientPermission do |error|
    render_problem(status: :forbidden, code: "insufficient_permission", title: error.message, param: error.permission)
  end

  private

  def assign_request_context
    Current.request_id = request.request_id
    Current.source_surface = request_surface

    principal = Authenticator.call(request)
    if principal
      apply_principal!(principal)
    elsif Rails.configuration.x.header_auth
      apply_legacy_headers!
    end
  end

  def apply_principal!(principal)
    asserted_org = request.headers["X-Organization-Id"].presence
    if asserted_org && asserted_org != principal.organization_id
      raise Authenticator::Forbidden.new("organization_mismatch", "X-Organization-Id does not match the credential's organization.")
    end

    Current.principal = principal
    Current.organization_id = principal.organization_id
    Current.actor_id = principal.user_id
    Current.actor_type = principal.actor_type
    Current.agent_id = principal.agent_id
    Current.credential_id = principal.credential_id
    Current.source_surface = "agent" if principal.agent && Current.source_surface.in?(%w[api web])
  end

  # Test/dev harness only (config.x.header_auth). Identity is asserted, not
  # proven; production never reaches this.
  def apply_legacy_headers!
    Current.organization_id = request.headers["X-Organization-Id"].presence
    Current.actor_id = request.headers["X-Actor-Id"].presence
    Current.actor_type = request.headers["X-Actor-Type"].presence || "user"
    Current.principal = Principal.legacy
  end

  def request_surface
    claimed = request.headers["X-Bigbuck-Surface"].to_s.downcase
    SURFACES.include?(claimed) ? claimed : "api"
  end
end
