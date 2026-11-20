# frozen_string_literal: true

# Per-request / per-job tenant and actor context. Unset org_id fails closed
# for tenant-scoped models (see TenantScoped).
#
# actor_id is the human the work is for: the signed-in user, or the user who
# owns the agent that is acting. Domain services use it for identity checks
# (approver, mailbox owner, interviewer). agent_id is set when an agent acts;
# audit rows then record the agent as the actor and the user as on_behalf_of.
class Current < ActiveSupport::CurrentAttributes
  attribute :organization_id
  attribute :actor_id
  attribute :actor_type
  attribute :agent_id
  attribute :credential_id
  attribute :principal
  attribute :source_surface
  attribute :request_id

  def organization_id!
    organization_id.presence || raise(TenantRequired, "Current.organization_id is required")
  end

  # Who audit history names as the actor.
  def audit_actor_id
    agent_id.presence || actor_id
  end

  # The user an agent acted for; nil when a user acted directly.
  def on_behalf_of_id
    agent_id.present? ? actor_id : nil
  end

  class TenantRequired < StandardError; end
end
