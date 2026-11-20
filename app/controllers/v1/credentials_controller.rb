# frozen_string_literal: true

module V1
  # Personal and integration API credentials. Personal tokens act for the caller
  # with scopes ∩ their role. Integration tokens act for the organization and
  # need integration.manage. Tokens are returned once, at creation.
  class CredentialsController < ApplicationController
    include IdentityHelpers

    before_action :forbid_agents!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: error.message, title: error.message.humanize)
    end

    def index
      rows = visible_credentials.where(kind: %w[personal integration agent]).order(created_at: :desc).limit(200)
      render json: { data: rows.map { |c| serialize_credential(c) } }
    end

    def create
      unless OauthAccessToken.legacy_tokens_allowed?
        return render_problem(status: :forbidden, code: "oauth_required", title: "Provision an OAuth identity instead of a personal or integration token.")
      end
      with_idempotency do
        kind = params.require(:kind).to_s
        raise ArgumentError, "unsupported_kind" unless %w[personal integration].include?(kind)

        user = nil
        if kind == "integration"
          require_permission!("integration.manage")
        else
          user = require_membership!.user
        end

        issued = CredentialIssuer.call(
          kind: kind, name: params.require(:name), user: user,
          scopes: Array(params[:scopes]), expires_at: parse_expires_at(params[:expires_at]),
          created_by: acting_membership&.user
        )
        render json: serialize_credential(issued.credential, token: issued.token), status: :created
      end
    end

    def revoke
      credential = visible_credentials.find(params[:id])
      credential.status = "revoked"
      credential.revoked_at = Time.current
      credential.version += 1
      ChangeWriter.call(record: credential, action: "api_credential.revoked", event_type: nil,
                        changes: { "status" => %w[active revoked] })
      render json: serialize_credential(credential)
    end

    private

    def visible_credentials
      return ApiCredential.all if permitted?("integration.manage")

      membership = acting_membership
      return ApiCredential.none unless membership

      own_agents = Agent.where(owner_membership_id: membership.id).select(:id)
      ApiCredential.where(user_id: membership.user_id).or(ApiCredential.where(agent_id: own_agents))
    end
  end
end
