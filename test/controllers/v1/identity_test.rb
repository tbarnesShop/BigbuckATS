# frozen_string_literal: true

require "test_helper"

# M9a: bearer credentials, sessions, agents and permission enforcement, with the
# legacy header harness switched off the way production runs.
class V1::IdentityTest < ActionDispatch::IntegrationTest
  setup do
    @header_auth_was = Rails.configuration.x.header_auth
    Rails.configuration.x.header_auth = false

    @provisioned = OrganizationProvisioner.call(
      name: "Acme", slug: "acme-#{SecureRandom.hex(4)}",
      owner_email: "owner-#{SecureRandom.hex(4)}@acme.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @owner = @provisioned[:user]
    @owner_membership = @provisioned[:membership]
    Current.organization_id = @org.id
    @hm_user = User.create!(email: "hm-#{SecureRandom.hex(3)}@acme.test", name: "HM")
    @hm_membership = Membership.create!(user: @hm_user, role: @provisioned[:roles].fetch("hiring_manager"), status: "active")
    Current.reset
  end

  teardown do
    Rails.configuration.x.header_auth = @header_auth_was
    Current.reset
  end

  test "legacy tenant and actor headers are ignored when header auth is off" do
    get "/v1/people", headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @owner.id }
    assert_response :unauthorized
    assert_equal "unauthenticated", response.parsed_body["code"]
  end

  test "an invalid or revoked token is rejected" do
    get "/v1/people", headers: bearer("bb_live_#{'x' * 40}")
    assert_response :unauthorized
    assert_equal "invalid_token", response.parsed_body["code"]

    issued = issue(kind: "session", user: @owner)
    within_org { issued.credential.revoke! }
    get "/v1/people", headers: bearer(issued.token)
    assert_response :unauthorized
  end

  test "an expired token is rejected" do
    issued = issue(kind: "session", user: @owner, expires_at: 1.minute.from_now)
    travel 2.minutes do
      get "/v1/people", headers: bearer(issued.token)
      assert_response :unauthorized
    end
  end

  test "a session token can read and write, and reports who is signed in" do
    issued = issue(kind: "session", user: @owner)

    get "/v1/sessions/current", headers: bearer(issued.token)
    assert_response :success
    body = response.parsed_body
    assert_equal @owner.id, body.dig("user", "id")
    assert_equal "user", body["actor_type"]
    assert_includes body["permissions"], "person.create"

    post "/v1/people", params: { person: { display_name: "Grace", email: "grace@example.com" } },
                       headers: bearer(issued.token), as: :json
    assert_response :created
  end

  test "sign out revokes the session" do
    issued = issue(kind: "session", user: @owner)
    delete "/v1/sessions/current", headers: bearer(issued.token)
    assert_response :no_content
    get "/v1/sessions/current", headers: bearer(issued.token)
    assert_response :unauthorized
  end

  test "an organization header that does not match the token is refused" do
    issued = issue(kind: "session", user: @owner)
    get "/v1/people", headers: bearer(issued.token).merge("X-Organization-Id" => Id.generate)
    assert_response :forbidden
    assert_equal "organization_mismatch", response.parsed_body["code"]
  end

  test "a personal token is limited to its scopes" do
    issued = issue(kind: "personal", user: @owner, scopes: %w[people:read])
    get "/v1/people", headers: bearer(issued.token)
    assert_response :success

    post "/v1/people", params: { person: { display_name: "Nope" } }, headers: bearer(issued.token), as: :json
    assert_response :forbidden
    assert_equal "insufficient_permission", response.parsed_body["code"]
    assert_equal "person.create", response.parsed_body["param"]
  end

  test "a role without the permission is refused" do
    issued = issue(kind: "session", user: @hm_user)
    post "/v1/people", params: { person: { display_name: "Nope" } }, headers: bearer(issued.token), as: :json
    assert_response :forbidden
  end

  test "members create agents, issue agent tokens, and agent writes are attributed to the agent" do
    session = issue(kind: "session", user: @owner)

    post "/v1/agents", params: { agent: { name: "Sourcer", scopes: %w[people:write] } },
                       headers: bearer(session.token), as: :json
    assert_response :created
    agent_id = response.parsed_body["id"]
    assert_equal @owner_membership.id, response.parsed_body["owner_membership_id"]

    post "/v1/agents/#{agent_id}/credentials", params: { name: "mcp" }, headers: bearer(session.token), as: :json
    assert_response :created
    token = response.parsed_body["token"]
    assert_match(/\Abb_live_/, token)
    assert_equal agent_id, response.parsed_body["agent_id"]

    post "/v1/people", params: { person: { display_name: "Found By Agent", email: "agent-find@example.com" } },
                       headers: bearer(token).merge("X-Bigbuck-Surface" => "mcp"), as: :json
    assert_response :created
    person_id = response.parsed_body["id"]

    audit = AuditEvent.unscoped.where(organization_id: @org.id, resource_id: person_id).order(:created_at).last
    assert_equal "agent", audit.actor_type
    assert_equal agent_id, audit.actor_id
    assert_equal @owner.id, audit.on_behalf_of_id
    assert_equal "mcp", audit.source_surface
    assert audit.credential_id.present?
  end

  test "an agent cannot exceed its owner's role" do
    agent = create_agent(owner: @hm_membership, scopes: %w[people:write])
    token = issue(kind: "agent", agent: agent).token
    post "/v1/people", params: { person: { display_name: "Nope" } }, headers: bearer(token), as: :json
    assert_response :forbidden
  end

  test "an agent cannot exceed its own scopes" do
    agent = create_agent(owner: @owner_membership, scopes: %w[people:read])
    token = issue(kind: "agent", agent: agent).token
    post "/v1/people", params: { person: { display_name: "Nope" } }, headers: bearer(token), as: :json
    assert_response :forbidden
  end

  test "agents cannot create agents or credentials" do
    agent = create_agent(owner: @owner_membership, scopes: %w[agents:write people:read])
    token = issue(kind: "agent", agent: agent).token
    post "/v1/agents", params: { agent: { name: "Child", scopes: %w[people:read] } }, headers: bearer(token), as: :json
    assert_response :forbidden
    assert_equal "agents_cannot_manage_identity", response.parsed_body["code"]

    post "/v1/credentials", params: { kind: "personal", name: "x", scopes: %w[people:read] }, headers: bearer(token), as: :json
    assert_response :forbidden
  end

  test "a paused agent is refused and a revoked agent's tokens stop working" do
    session = issue(kind: "session", user: @owner)
    agent = create_agent(owner: @owner_membership, scopes: %w[people:read])
    token = issue(kind: "agent", agent: agent).token

    post "/v1/agents/#{agent.id}/pause", headers: bearer(session.token)
    assert_response :success
    get "/v1/people", headers: bearer(token)
    assert_response :forbidden
    assert_equal "agent_inactive", response.parsed_body["code"]

    post "/v1/agents/#{agent.id}/resume", headers: bearer(session.token)
    get "/v1/people", headers: bearer(token)
    assert_response :success

    post "/v1/agents/#{agent.id}/revoke", headers: bearer(session.token)
    assert_response :success
    get "/v1/people", headers: bearer(token)
    assert_response :unauthorized
  end

  test "a user can act as their own agent but not someone else's" do
    session = issue(kind: "session", user: @owner)
    mine = create_agent(owner: @owner_membership, scopes: %w[people:write])
    theirs = create_agent(owner: @hm_membership, scopes: %w[people:read])

    get "/v1/sessions/current", headers: bearer(session.token).merge("X-Bigbuck-Act-As-Agent" => mine.id)
    assert_response :success
    assert_equal "agent", response.parsed_body["actor_type"]
    assert_equal mine.id, response.parsed_body.dig("agent", "id")
    refute_includes response.parsed_body["permissions"], "job.manage"

    get "/v1/people", headers: bearer(session.token).merge("X-Bigbuck-Act-As-Agent" => theirs.id)
    assert_response :forbidden
    assert_equal "act_as_not_allowed", response.parsed_body["code"]
  end

  test "agents list only shows the caller's own agents without agent.manage" do
    create_agent(owner: @owner_membership, scopes: %w[people:read])
    create_agent(owner: @hm_membership, scopes: %w[people:read])

    get "/v1/agents", headers: bearer(issue(kind: "session", user: @hm_user).token)
    assert_response :success
    assert_equal [ @hm_membership.id ], response.parsed_body["data"].map { |a| a["owner_membership_id"] }.uniq

    get "/v1/agents", headers: bearer(issue(kind: "session", user: @owner).token)
    assert_equal 2, response.parsed_body["data"].size
  end

  test "integration credentials need integration.manage and act org-wide within their scopes" do
    post "/v1/credentials", params: { kind: "integration", name: "ats-sync", scopes: %w[people:read] },
                            headers: bearer(issue(kind: "session", user: @hm_user).token), as: :json
    assert_response :forbidden

    post "/v1/credentials", params: { kind: "integration", name: "ats-sync", scopes: %w[people:read] },
                            headers: bearer(issue(kind: "session", user: @owner).token), as: :json
    assert_response :created
    token = response.parsed_body["token"]
    refute ApiCredential.unscoped.where(token_digest: token).exists?, "plaintext token must never be stored"

    get "/v1/people", headers: bearer(token)
    assert_response :success
    get "/v1/sessions/current", headers: bearer(token)
    assert_equal "integration", response.parsed_body["actor_type"]
  end

  test "unknown scopes are rejected" do
    post "/v1/credentials", params: { kind: "personal", name: "x", scopes: %w[people:everything] },
                            headers: bearer(issue(kind: "session", user: @owner).token), as: :json
    assert_response :unprocessable_entity
  end

  test "a handoff code is exchanged once for a session" do
    handoff = issue(kind: "handoff", user: @owner, expires_at: 2.minutes.from_now)

    get "/v1/people", headers: bearer(handoff.token)
    assert_response :unauthorized, "a handoff code is never a bearer token"

    post "/v1/sessions/exchange", params: { code: handoff.token }, as: :json
    assert_response :created
    session_token = response.parsed_body.dig("session", "token")
    assert_match(/\Abb_sess_/, session_token)

    post "/v1/sessions/exchange", params: { code: handoff.token }, as: :json
    assert_response :unauthorized

    get "/v1/people", headers: bearer(session_token)
    assert_response :success
  end

  test "demo email sign-in issues a session and can be switched off" do
    Current.organization_id = @org.id
    GoogleSignIn.verify_domain!(domain: "acme.test")
    Current.reset

    post "/v1/sessions", params: { email: @owner.email, slug: @org.slug }, as: :json
    assert_response :forbidden
    assert_equal "demo_tenant_required", response.parsed_body["code"]
    DemoSandbox.find_or_initialize_by(surface: "ui").update!(organization_id: @org.id, generation: 1, state: "ready", resets_at: 1.hour.from_now)
    post "/v1/sessions", params: { email: @owner.email, slug: @org.slug }, as: :json
    assert_response :created
    assert_match(/\Abb_sess_/, response.parsed_body.dig("session", "token"))
    refute response.parsed_body.key?("headers")

    was = Rails.configuration.x.demo_sign_in
    Rails.configuration.x.demo_sign_in = false
    post "/v1/sessions", params: { email: @owner.email, slug: @org.slug }, as: :json
    assert_response :forbidden
    assert_equal "demo_sign_in_disabled", response.parsed_body["code"]
  ensure
    Rails.configuration.x.demo_sign_in = was unless was.nil?
  end

  test "public endpoints still work without a credential" do
    get "/v1/health"
    assert_response :success
  end

  test "role presets only use known permissions" do
    Permissions::PRESETS.each_value do |perms|
      assert_empty perms - Permissions::ALL
    end
    Scopes::MAP.each_value do |perms|
      assert_empty perms - Permissions::ALL
    end
    Authorization::ACTION_PERMISSIONS.each_value do |perm|
      assert_includes Permissions::ALL, perm
    end
  end

  private

  def bearer(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def within_org
    Current.organization_id = @org.id
    yield
  ensure
    Current.reset
  end

  def issue(kind:, user: nil, agent: nil, scopes: [], expires_at: 1.hour.from_now)
    within_org do
      CredentialIssuer.call(kind: kind, name: "test #{kind}", user: user, agent: agent,
                            scopes: scopes, expires_at: expires_at, audit: false)
    end
  end

  def create_agent(owner:, scopes:)
    within_org do
      Agent.create!(owner_membership: owner, name: "agent-#{SecureRandom.hex(3)}", scopes: scopes)
    end
  end
end
