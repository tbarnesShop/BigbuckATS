# frozen_string_literal: true

# Shared helpers for the identity endpoints (sessions, agents, credentials).
module IdentityHelpers
  extend ActiveSupport::Concern

  private

  # The membership of the human behind this request, for both real principals
  # and the legacy header harness.
  def acting_membership
    return @acting_membership if defined?(@acting_membership)

    @acting_membership =
      if current_principal
        current_principal.membership
      elsif Current.actor_id.present?
        Membership.find_by(user_id: Current.actor_id, status: "active")
      end
  end

  # Agents may not mint agents or credentials; only people can.
  def forbid_agents!
    return unless current_principal&.agent

    raise Authenticator::Forbidden.new("agents_cannot_manage_identity", "Agents cannot create or change agents or credentials.")
  end

  def require_membership!
    return acting_membership if acting_membership

    raise Authenticator::Forbidden.new("membership_required", "Only a member of the organization can do this.")
  end

  def serialize_agent(agent)
    {
      "id" => agent.id,
      "organization_id" => agent.organization_id,
      "owner_membership_id" => agent.owner_membership_id,
      "owner_user_id" => agent.owner_user_id,
      "name" => agent.name,
      "description" => agent.description,
      "status" => agent.status,
      "scopes" => agent.scopes,
      "version" => agent.version,
      "paused_at" => agent.paused_at,
      "revoked_at" => agent.revoked_at,
      "created_at" => agent.created_at,
      "updated_at" => agent.updated_at
    }
  end

  def serialize_credential(credential, token: nil)
    body = {
      "id" => credential.id,
      "kind" => credential.kind,
      "name" => credential.name,
      "token_prefix" => credential.token_prefix,
      "scopes" => credential.scopes,
      "user_id" => credential.user_id,
      "agent_id" => credential.agent_id,
      "api_version" => credential.api_version,
      "status" => credential.status,
      "expires_at" => credential.expires_at,
      "last_used_at" => credential.last_used_at,
      "created_at" => credential.created_at,
      "version" => credential.version
    }
    body["token"] = token if token
    body
  end

  def parse_expires_at(raw)
    return nil if raw.blank?

    time = Time.iso8601(raw.to_s)
    raise ArgumentError, "expires_at_in_past" unless time.future?

    time
  rescue ArgumentError => e
    raise e if e.message == "expires_at_in_past"

    raise ArgumentError, "invalid_expires_at"
  end
end
