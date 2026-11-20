# frozen_string_literal: true

# Resolves a request's bearer credential to a Principal. Raises Unauthenticated
# for a presented-but-invalid token, or Forbidden for a valid token that may not
# act (inactive membership, paused agent, act-as on someone else's agent).
class Authenticator
  ACT_AS_HEADER = "X-Bigbuck-Act-As-Agent"

  class Error < StandardError
    attr_reader :code

    def initialize(code, message = code)
      @code = code
      super(message)
    end
  end
  Unauthenticated = Class.new(Error)
  Forbidden = Class.new(Error)

  def self.bearer_token(request)
    header = request.headers["Authorization"].to_s
    return nil unless header.start_with?("Bearer ")

    header.delete_prefix("Bearer ").strip.presence
  end

  # Returns nil when the request carries no bearer token.
  def self.call(request)
    token = bearer_token(request)
    return nil if token.nil?

    unless token.match?(ApiCredential::TOKEN_PATTERN)
      return OauthAccessToken.principal(token, act_as_agent_id: request.headers[ACT_AS_HEADER].presence) if OauthAccessToken.enabled?
    end
    credential = ApiCredential.find_bearer(token)
    raise Unauthenticated.new("invalid_token", "The bearer token is not valid, has expired or was revoked.") unless credential
    if credential.kind.in?(%w[personal integration]) && !OauthAccessToken.legacy_tokens_allowed?
      raise Unauthenticated.new("oauth_required", "Use an OAuth access token for API and CLI access.")
    end

    principal_for(credential, act_as_agent_id: request.headers[ACT_AS_HEADER].presence)
  end

  def self.principal_for(credential, act_as_agent_id: nil)
    org_id = credential.organization_id
    Current.organization_id = org_id
    org = Organization.find(org_id)

    case credential.kind
    when "integration"
      raise Forbidden.new("act_as_not_allowed") if act_as_agent_id
      build(credential, org_id, user: nil, membership: nil, agent: nil,
                                permissions: Scopes.permissions_for(credential.scopes))
    when "agent"
      raise Forbidden.new("act_as_not_allowed") if act_as_agent_id
      agent = Agent.find_by(id: credential.agent_id)
      for_agent(credential, org_id, agent, scopes_limit: nil)
    when "personal", "session"
      user = User.find(credential.user_id)
      membership = active_membership!(user, org)
      role_permissions = membership.role.permissions.to_set
      permissions =
        if credential.kind == "session" then role_permissions
        else role_permissions & Scopes.permissions_for(credential.scopes)
        end

      if act_as_agent_id
        agent = Agent.find_by(id: act_as_agent_id)
        unless agent && agent.owner_membership_id == membership.id
          raise Forbidden.new("act_as_not_allowed", "You can only act as an agent you own.")
        end
        limit = credential.kind == "session" ? nil : Scopes.permissions_for(credential.scopes)
        return for_agent(credential, org_id, agent, scopes_limit: limit)
      end

      build(credential, org_id, user: user, membership: membership, agent: nil, permissions: permissions)
    else
      raise Unauthenticated.new("invalid_token")
    end
  end

  def self.for_agent(credential, org_id, agent, scopes_limit:)
    raise Forbidden.new("agent_inactive", "This agent is paused or revoked.") unless agent&.active?

    membership = agent.owner_membership
    owner = membership.user
    permissions = membership.role.permissions.to_set & Scopes.permissions_for(agent.scopes)
    permissions &= scopes_limit if scopes_limit
    build(credential, org_id, user: owner, membership: membership, agent: agent, permissions: permissions)
  end

  def self.active_membership!(user, org)
    membership = Membership.find_by(user_id: user.id, organization_id: org.id)
    unless membership&.status == "active"
      raise Forbidden.new("membership_inactive", "This user is not an active member of the organization.")
    end

    membership
  end

  def self.build(credential, org_id, user:, membership:, agent:, permissions:)
    credential.touch_last_used!
    Principal.new(
      organization_id: org_id, credential: credential, user: user, membership: membership,
      agent: agent, permissions: permissions, api_version: credential.api_version
    )
  end

  private_class_method :for_agent, :active_membership!, :build
end
