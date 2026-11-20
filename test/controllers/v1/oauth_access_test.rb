require "test_helper"
require "jwt"

class V1::OauthAccessTest < ActionDispatch::IntegrationTest
  ISSUER = "https://identity.example.test/"
  ENV_KEYS = %w[BIGBUCK_OAUTH_ISSUER BIGBUCK_OAUTH_AUDIENCE BIGBUCK_OAUTH_JWKS_URI BIGBUCK_OAUTH_ACCESS_TOKEN_TYP
    BIGBUCK_OAUTH_CLIENT_ID_CLAIM BIGBUCK_OAUTH_MAX_TOKEN_SECONDS BIGBUCK_ALLOW_LEGACY_API_TOKENS].freeze

  setup do
    @prior = ENV.to_hash.slice(*ENV_KEYS)
    ENV_KEYS.each { |key| ENV.delete(key) }
    ENV["BIGBUCK_OAUTH_ISSUER"] = ISSUER
    ENV["BIGBUCK_OAUTH_AUDIENCE"] = "https://bigbuck.example.test/api"
    ENV["BIGBUCK_OAUTH_JWKS_URI"] = "#{ISSUER}keys"
    @old_header = Rails.configuration.x.header_auth
    Rails.configuration.x.header_auth = false
    data = OrganizationProvisioner.call(name: "OAuth", slug: "oauth-#{SecureRandom.hex(4)}",
      owner_email: "owner-#{SecureRandom.hex(4)}@example.test", owner_name: "Owner")
    @org = data[:organization]
    @owner = data[:user]
    @membership = data[:membership]
    @roles = data[:roles]
    Current.organization_id = @org.id
    @identity = OauthIdentity.create!(name: "CLI", issuer: ISSUER, subject: "provider-user-123", client_id: "native-cli",
      kind: "human", membership: @membership, scopes: %w[people:read jobs:read])
    @person = Person.create!(display_name: "Private candidate")
    @key = OpenSSL::PKey::RSA.generate(2048)
    @jwk = JWT::JWK.new(@key, "trusted")
    @keys = JWT::JWK::Set.new(@jwk)
    OauthAccessToken.instance_variable_set(:@cache, { uri: ENV["BIGBUCK_OAUTH_JWKS_URI"],
      at: Process.clock_gettime(Process::CLOCK_MONOTONIC), keys: @keys })
    Current.reset
  end

  teardown do
    ENV_KEYS.each { |key| @prior.key?(key) ? ENV[key] = @prior[key] : ENV.delete(key) }
    Rails.configuration.x.header_auth = @old_header
    OauthAccessToken.reset_keys!
    Current.reset
  end

  def claims
    { "iss" => ISSUER, "aud" => ENV["BIGBUCK_OAUTH_AUDIENCE"], "sub" => @identity.subject,
      "client_id" => @identity.client_id, "iat" => Time.current.to_i, "exp" => 10.minutes.from_now.to_i,
      "scope" => "people:read jobs:read" }
  end

  def token(overrides = {}, key: @key, headers: {}, **extra)
    JWT.encode(claims.merge(overrides).merge(extra), key, "RS256", { "kid" => "trusted", "typ" => "at+jwt" }.merge(headers))
  end

  def request_with(value, method: :get, path: "/v1/people", params: nil, headers: {})
    public_send(method, path, headers: { "Authorization" => "Bearer #{value}" }.merge(headers), params: params, as: :json)
  end

  test "valid OAuth access preserves tenant identity scopes and attribution" do
    request_with(token)
    assert_response :success
    assert_equal @person.id, response.parsed_body["data"].first["id"]
    request_with(token(headers: { "jku" => "https://attacker.test/keys", "x5u" => "https://attacker.test/cert" }), path: "/v1/sessions/current")
    assert_response :success
    assert_equal @org.id, response.parsed_body["organization_id"]
    assert_equal @owner.id, response.parsed_body.dig("user", "id")
    assert_equal "oauth", response.parsed_body.dig("credential", "kind")
    assert_equal @identity.id, response.parsed_body.dig("credential", "id")
    refute_includes response.parsed_body["permissions"], "person.create"
  end

  test "rejects bad signature issuer audience client subject type expiry and lifetime" do
    values = [ token(key: OpenSSL::PKey::RSA.generate(2048)), token("iss" => "https://attacker.example/"),
      token("aud" => "google-client-id"), token("client_id" => "other-client"), token("sub" => "other-user"),
      token(headers: { "typ" => "JWT" }), token("exp" => 1.minute.ago.to_i), token("iat" => 5.minutes.from_now.to_i),
      token("exp" => 1.hour.from_now.to_i), token("scope" => [ "people:read" ]) ]
    values.each do |value|
      request_with(value)
      assert_response :unauthorized
    end
    request_with(JWT.encode(claims, "attacker", "HS256", { kid: "trusted", typ: "at+jwt" }))
    assert_response :unauthorized
    request_with(token(headers: { "kid" => "unknown" }))
    assert_response :unauthorized
  end

  test "identity revocation and membership deactivation apply to already issued tokens" do
    issued = token
    Current.set(organization_id: @org.id) { @identity.update!(status: "revoked", revoked_at: Time.current) }
    request_with(issued)
    assert_response :unauthorized
    Current.set(organization_id: @org.id) do
      @identity.update!(status: "active", revoked_at: nil)
      @membership.update!(status: "inactive")
    end
    request_with(issued)
    assert_response :forbidden
  end

  test "provider tenant email and role claims never grant access or override the binding" do
    request_with(token("organization_id" => Id.generate, "email" => "someone@example.test", "roles" => [ "owner" ]))
    assert_response :success
    request_with(token("scope" => "people:read people:write"), method: :post,
      params: { person: { display_name: "Unapproved write" } })
    assert_response :forbidden
    request_with(token("scope" => ""))
    assert_response :forbidden
  end

  test "local role remains a ceiling even if provider and binding allow a write" do
    Current.set(organization_id: @org.id) do
      @identity.update!(scopes: %w[people:read people:write])
      @membership.update!(role: @roles.fetch("hiring_manager"))
    end
    request_with(token("scope" => "people:write"), method: :post, params: { person: { display_name: "Unapproved" } })
    assert_response :forbidden
  end

  test "dedicated service identities have only their explicitly provisioned scopes" do
    Current.set(organization_id: @org.id) do
      OauthIdentity.create!(name: "Nightly import", issuer: ISSUER, subject: "service-123", client_id: "service-client",
        kind: "service", scopes: %w[people:read])
    end
    issued = token("sub" => "service-123", "client_id" => "service-client", "scope" => "people:read people:write")
    request_with(issued, path: "/v1/sessions/current")
    assert_response :success
    assert_nil response.parsed_body["user"]
    assert_equal "integration", response.parsed_body["actor_type"]
    request_with(issued, method: :post, params: { person: { display_name: "Unapproved" } })
    assert_response :forbidden
  end

  test "identity provisioning requires integration permission and tenant-correct membership" do
    request_with(token, method: :post, path: "/v1/oauth_identities",
      params: { oauth_identity: { name: "Bad", subject: "bad", client_id: "cli", kind: "service", scopes: [ "people:read" ] } })
    assert_response :forbidden
    other = OrganizationProvisioner.call(name: "Other", slug: "other-#{SecureRandom.hex(4)}",
      owner_email: "other-#{SecureRandom.hex(4)}@example.test", owner_name: "Other")
    Current.set(organization_id: @org.id) do
      assert_raises(ActiveRecord::InvalidForeignKey) do
        identity = OauthIdentity.new(name: "Cross tenant", issuer: ISSUER, subject: "cross", client_id: "cli",
          kind: "human", membership_id: other[:membership].id, scopes: [ "people:read" ])
        identity.binding_digest = OauthIdentity.digest(ISSUER, "cross", "cli")
        identity.organization_id = @org.id
        identity.save!(validate: false)
      end
    end
  end

  test "legacy personal tokens are rejected when OAuth is configured unless explicitly allowed" do
    issued = Current.set(organization_id: @org.id) do
      CredentialIssuer.call(kind: "personal", name: "Old", user: @owner, scopes: [ "people:read" ])
    end
    get "/v1/people", headers: { "Authorization" => "Bearer #{issued.token}" }
    assert_response :unauthorized
    ENV["BIGBUCK_ALLOW_LEGACY_API_TOKENS"] = "1"
    get "/v1/people", headers: { "Authorization" => "Bearer #{issued.token}" }
    assert_response :success
  end

  test "partial or unsafe configuration fails closed" do
    issued = Current.set(organization_id: @org.id) do
      CredentialIssuer.call(kind: "personal", name: "Old", user: @owner, scopes: [ "people:read" ])
    end
    ENV.delete("BIGBUCK_OAUTH_AUDIENCE")
    request_with(issued.token)
    assert_response :unauthorized
    request_with(token)
    assert_response :unauthorized
    ENV["BIGBUCK_OAUTH_AUDIENCE"] = "https://bigbuck.example.test/api"
    ENV["BIGBUCK_OAUTH_ISSUER"] = "http://insecure.example.test/"
    request_with(token("iss" => ENV["BIGBUCK_OAUTH_ISSUER"]))
    assert_response :unauthorized
  end

  test "administrators provision audit and revoke a dedicated binding" do
    Current.set(organization_id: @org.id) { @identity.update!(scopes: [ "credentials:manage" ]) }
    admin = token("scope" => "credentials:manage")
    request_with(admin, method: :post, path: "/v1/oauth_identities", params: {
      oauth_identity: { name: "Import job", subject: "job-123", client_id: "import-client", kind: "service", scopes: [ "people:read" ] }
    })
    assert_response :created
    id = response.parsed_body["id"]
    Current.set(organization_id: @org.id) do
      audit = AuditEvent.where(action: "oauth_identity.created", resource_id: id).sole
      assert_equal AuditHasher.digest(@org.id, "job-123"), audit.change_set["subject"].last
      refute audit.change_set.key?("binding_digest")
    end
    request_with(admin, path: "/v1/oauth_identities")
    assert_response :success
    request_with(admin, method: :post, path: "/v1/oauth_identities/#{id}/revoke")
    assert_response :success
    request_with(token("sub" => "job-123", "client_id" => "import-client", "scope" => "people:read"))
    assert_response :unauthorized
  end

  test "identity model rejects empty unknown and malformed identity grants" do
    Current.set(organization_id: @org.id) do
      identity = OauthIdentity.new(name: "Invalid", issuer: ISSUER, subject: "invalid", client_id: "cli", kind: "human")
      refute identity.valid?
      assert identity.errors[:membership].any?
      identity.kind = "service"
      identity.scopes = [ "owner:all" ]
      refute identity.valid?
      assert identity.errors[:scopes].any?
    end
  end

  test "OAuth act-as obeys agent and identity ceilings and rejects tenant overrides" do
    agent = Current.set(organization_id: @org.id) do
      Agent.create!(name: "Owned", owner_membership: @membership, scopes: %w[people:read people:write])
    end
    request_with(token, path: "/v1/sessions/current", headers: { "X-Bigbuck-Act-As-Agent" => agent.id })
    assert_response :success
    assert_equal "agent", response.parsed_body["actor_type"]
    refute_includes response.parsed_body["permissions"], "person.create"
    refute_includes response.parsed_body["permissions"], "job.read"
    Current.set(organization_id: @org.id) { agent.update!(status: "paused") }
    request_with(token, headers: { "X-Bigbuck-Act-As-Agent" => agent.id })
    assert_response :forbidden
    request_with(token, headers: { "X-Organization-Id" => Id.generate })
    assert_response :forbidden
  end
end
