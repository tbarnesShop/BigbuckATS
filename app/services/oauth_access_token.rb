# frozen_string_literal: true

require "net/http"
require "jwt"

# Resource-server verification only. Signing keys come from an administrator-
# configured HTTPS endpoint, never jku/x5u/issuer fields supplied by a token.
class OauthAccessToken
  MAX_TOKEN_BYTES = 16_384
  MAX_JWKS_BYTES = 256_000
  KEY_TTL = 5.minutes
  REFRESH_INTERVAL = 30.seconds
  MUTEX = Mutex.new

  Credential = Struct.new(:id, :name, :expires_at, keyword_init: true) do
    def kind = "oauth"
    def api_version = ApiCredential::CURRENT_API_VERSION
  end

  class << self
    def issuer = ENV["BIGBUCK_OAUTH_ISSUER"].presence
    def audience = ENV["BIGBUCK_OAUTH_AUDIENCE"].presence
    def jwks_uri = ENV["BIGBUCK_OAUTH_JWKS_URI"].presence
    def configured? = issuer.present? && audience.present? && jwks_uri.present?
    def enabled? = [ issuer, audience, jwks_uri ].any?(&:present?)
    def legacy_tokens_allowed? = !enabled? || ENV["BIGBUCK_ALLOW_LEGACY_API_TOKENS"] == "1"

    def verify(token)
      reject! unless configured? && token.bytesize <= MAX_TOKEN_BYTES
      trusted_https_uri(issuer, allow_query: false)
      trusted_https_uri(jwks_uri)
      max_lifetime = Integer(ENV.fetch("BIGBUCK_OAUTH_MAX_TOKEN_SECONDS", "900"))
      reject! unless max_lifetime.between?(1, 900)
      claim = ENV.fetch("BIGBUCK_OAUTH_CLIENT_ID_CLAIM", "client_id")
      reject! unless claim.match?(/\A[a-zA-Z0-9_]+\z/)
      payload, header = JWT.decode(token, nil, true,
        algorithms: [ "RS256" ], jwks: method(:keys),
        iss: issuer, verify_iss: true, aud: audience, verify_aud: true,
        verify_iat: { leeway: 30 }, leeway: 30,
        required_claims: [ "iss", "aud", "sub", "exp", "iat", claim ])
      reject! unless header["typ"] == ENV.fetch("BIGBUCK_OAUTH_ACCESS_TOKEN_TYP", "at+jwt")
      reject! unless payload["sub"].is_a?(String) && payload["sub"].present? && payload[claim].is_a?(String) && payload[claim].present?
      reject! unless payload["scope"].is_a?(String)
      reject! unless payload["exp"].is_a?(Integer) && payload["iat"].is_a?(Integer)
      lifetime = payload["exp"] - payload["iat"]
      reject! unless lifetime.positive? && lifetime <= max_lifetime
      reject! if payload[claim] == audience # do not accept a client ID as an API resource audience
      payload.merge("client_id" => payload[claim])
    rescue JWT::DecodeError, ArgumentError, TypeError
      reject!
    end

    def principal(token, act_as_agent_id: nil)
      payload = verify(token)
      # Privileged global lookup by an exact digest of verified issuer/subject/client.
      identity = OauthIdentity.unscoped.find_by(binding_digest: OauthIdentity.digest(payload["iss"], payload["sub"], payload["client_id"]))
      reject! unless identity&.active?
      Current.organization_id = identity.organization_id
      scopes = payload["scope"].split & identity.scopes
      permissions = Scopes.permissions_for(scopes)
      membership = identity.kind == "human" ? Membership.find_by(id: identity.membership_id) : nil
      reject! if identity.kind == "human" && membership.nil?
      if membership
        raise Authenticator::Forbidden.new("membership_inactive") unless membership.status == "active"
        permissions &= membership.role.permissions.to_set
      end
      user = membership&.user
      agent = nil
      if act_as_agent_id
        raise Authenticator::Forbidden.new("act_as_not_allowed") unless membership
        agent = Agent.find_by(id: act_as_agent_id)
        raise Authenticator::Forbidden.new("act_as_not_allowed") unless agent&.active? && agent.owner_membership_id == membership.id
        permissions &= Scopes.permissions_for(agent.scopes)
      end
      Principal.new(organization_id: identity.organization_id,
        credential: Credential.new(id: identity.id, name: identity.name, expires_at: Time.at(payload["exp"]).utc),
        user: user, membership: membership, agent: agent, permissions: permissions,
        api_version: ApiCredential::CURRENT_API_VERSION)
    end

    def reset_keys!
      MUTEX.synchronize { @cache = @last_attempt = nil }
    end

    private

    def reject!
      raise Authenticator::Unauthenticated.new("invalid_oauth_token", "The OAuth access token is invalid, expired, or not provisioned for this API.")
    end

    def keys(options)
      MUTEX.synchronize do
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        stale = @cache.nil? || @cache[:uri] != jwks_uri || now - @cache[:at] >= KEY_TTL
        if stale || (options[:kid_not_found] && now - @cache[:at] >= REFRESH_INTERVAL)
          if @last_attempt && @last_attempt[:uri] == jwks_uri && now - @last_attempt[:at] < REFRESH_INTERVAL
            reject! if stale
            return @cache[:keys]
          end
          @last_attempt = { uri: jwks_uri, at: now }
          @cache = { uri: jwks_uri, at: now, keys: fetch_keys }
        end
        @cache[:keys]
      end
    end

    def trusted_https_uri(value, allow_query: true)
      uri = URI.parse(value)
      reject! unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && uri.fragment.nil? && (allow_query || uri.query.nil?)
      uri
    rescue URI::InvalidURIError
      reject!
    end

    def fetch_keys
      uri = trusted_https_uri(jwks_uri)
      body = +""
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 3) do |http|
        http.request(Net::HTTP::Get.new(uri.request_uri)) do |response|
          reject! unless response.is_a?(Net::HTTPSuccess)
          response.read_body do |chunk|
            body << chunk
            reject! if body.bytesize > MAX_JWKS_BYTES
          end
        end
      end
      data = JSON.parse(body)
      reject! unless data.is_a?(Hash) && data["keys"].is_a?(Array)
      set = JWT::JWK::Set.new(data)
      set.select! { |key| key[:kty] == "RSA" && key[:use].in?([ nil, "sig" ]) && key[:alg].in?([ nil, "RS256" ]) && key.verify_key.n.num_bits >= 2048 }
      reject! if set.none?
      set
    rescue JSON::ParserError, URI::InvalidURIError, SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError,
      JWT::JWKError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError, NoMethodError
      reject!
    end
  end
end
