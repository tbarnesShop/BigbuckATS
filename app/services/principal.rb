# frozen_string_literal: true

# Who is calling, resolved from a verified credential. Immutable per request.
class Principal
  attr_reader :organization_id, :credential, :user, :membership, :agent, :permissions, :api_version

  def initialize(organization_id:, credential:, user:, membership:, agent:, permissions:, api_version:)
    @organization_id = organization_id
    @credential = credential
    @user = user
    @membership = membership
    @agent = agent
    effective_permissions = permissions.to_set
    effective_permissions.delete("person.erase") unless user && agent.nil? && membership&.role&.key == "owner"
    @permissions = effective_permissions.freeze
    @api_version = api_version
  end

  # Legacy header harness (test/dev only, see config.x.header_auth): identity is
  # asserted, not proven, and permissions are not checked.
  def self.legacy
    :legacy
  end

  def actor_type
    if agent then "agent"
    elsif user then "user"
    else "integration"
    end
  end

  # The human the work is for (see Current).
  def user_id
    user&.id
  end

  def agent_id
    agent&.id
  end

  def credential_id
    credential&.id
  end

  def can?(permission)
    permissions.include?(permission.to_s)
  end

  def org_wide?
    membership.nil? || membership.org_wide?
  end

  def as_json(*)
    {
      "organization_id" => organization_id,
      "actor_type" => actor_type,
      "credential" => credential && {
        "id" => credential.id, "kind" => credential.kind, "name" => credential.name,
        "expires_at" => credential.expires_at
      },
      "user" => user && { "id" => user.id, "email" => user.email, "name" => user.name },
      "membership" => membership && { "id" => membership.id, "role_key" => membership.role&.key },
      "agent" => agent && { "id" => agent.id, "name" => agent.name },
      "permissions" => permissions.to_a.sort,
      "api_version" => api_version
    }
  end
end
