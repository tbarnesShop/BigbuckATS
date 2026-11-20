# frozen_string_literal: true

require "oauth2"
require "googleauth/id_tokens"
require "json"

# Authorization-code Google OAuth for verified-domain sign-in.
# Tokens are exchanged server-side; refresh tokens belong in Secret Manager later.
class GoogleOauth
  Error = Class.new(StandardError)
  NotConfigured = Class.new(Error)
  ExchangeFailed = Class.new(Error)

  AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
  TOKEN_URL = "https://oauth2.googleapis.com/token"
  USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"
  SCOPES = %w[openid email profile].freeze

  def self.configured?
    client_id.present? && client_secret.present? && redirect_uri.present?
  end

  def self.client_id = ENV["GOOGLE_CLIENT_ID"].to_s.presence
  def self.client_secret = ENV["GOOGLE_CLIENT_SECRET"].to_s.presence
  def self.redirect_uri = ENV["GOOGLE_REDIRECT_URI"].to_s.presence
  def self.web_origin = ENV.fetch("WEB_ORIGIN", "http://127.0.0.1:44100").to_s.sub(%r{/\z}, "")

  def self.authorization_url(state:, code_challenge: nil, nonce: nil)
    raise NotConfigured, "google_oauth_not_configured" unless configured?

    params = {
      client_id: client_id,
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: SCOPES.join(" "),
      access_type: "online",
      include_granted_scopes: "true",
      prompt: "select_account",
      state: state,
      code_challenge: code_challenge, code_challenge_method: "S256", nonce: nonce
    }
    "#{AUTH_URL}?#{URI.encode_www_form(params)}"
  end

  def self.exchange_code!(code:, code_verifier:, nonce:)
    raise NotConfigured, "google_oauth_not_configured" unless configured?
    client = OAuth2::Client.new(client_id, client_secret, site: "https://accounts.google.com",
      authorize_url: AUTH_URL, token_url: TOKEN_URL, connection_opts: { request: { timeout: 10, open_timeout: 3 } })
    token = client.auth_code.get_token(code, redirect_uri: redirect_uri, code_verifier: code_verifier)
    id_token = token.params.fetch("id_token")
    claims = Google::Auth::IDTokens.verify_oidc(id_token, aud: client_id)
    raise ExchangeFailed, "invalid_nonce" unless claims["nonce"].is_a?(String) &&
      ActiveSupport::SecurityUtils.secure_compare(claims["nonce"], nonce)
    email = claims["email"].to_s.downcase
    raise ExchangeFailed, "email_not_verified" unless claims["email_verified"] == true && email.present?
    { email: email, name: claims["name"].presence || email.split("@").first, sub: claims.fetch("sub") }
  rescue OAuth2::Error, Google::Auth::IDTokens::VerificationError, KeyError
    raise ExchangeFailed, "provider_verification_failed"
  end
end
