require "test_helper"
class GoogleTransactionTest < ActionDispatch::IntegrationTest
  setup do
    @prior = ENV.to_hash.slice("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET", "GOOGLE_REDIRECT_URI", "WEB_ORIGIN")
    ENV["GOOGLE_CLIENT_ID"] = "client"
    ENV["GOOGLE_CLIENT_SECRET"] = "secret"
    ENV["GOOGLE_REDIRECT_URI"] = "https://api.example.test/v1/oauth/google/callback"
    ENV["WEB_ORIGIN"] = "https://app.example.test"
    data = OrganizationProvisioner.call(name: "Login", slug: "login-#{SecureRandom.hex(4)}",
      owner_email: "login-#{SecureRandom.hex(4)}@example.test", owner_name: "Owner")
    @org = data[:organization]
    @owner = data[:user]
    Current.set(organization_id: @org.id) { GoogleSignIn.verify_domain!(domain: "example.test") }
    @original_exchange = GoogleOauth.method(:exchange_code!)
    owner = @owner
    GoogleOauth.define_singleton_method(:exchange_code!) do |code:, code_verifier:, nonce:|
      raise "PKCE missing" unless code_verifier.present? && nonce.present?
      { email: owner.email, name: owner.name, sub: "subject" }
    end
  end
  teardown do
    @prior_keys = %w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_REDIRECT_URI WEB_ORIGIN]
    @prior_keys.each { |name| @prior.key?(name) ? ENV[name] = @prior[name] : ENV.delete(name) }
    GoogleOauth.define_singleton_method(:exchange_code!, @original_exchange)
    Current.reset
  end
  test "callback is bound to the initiating browser and consumed exactly once" do
    get "/v1/oauth/google", params: { slug: @org.slug }
    authorize = URI(response.redirect_url)
    query = URI.decode_www_form(authorize.query).to_h
    assert_equal "S256", query["code_challenge_method"]
    assert query["nonce"].present?
    state = query.fetch("state")
    other = ActionDispatch::Integration::Session.new(Rails.application)
    other.get "/v1/oauth/google/callback", params: { state: state, code: "code" }
    assert_includes other.response.redirect_url, "invalid_state"
    get "/v1/oauth/google/callback", params: { state: state, code: "code" }
    assert_includes response.redirect_url, "code="
    get "/v1/oauth/google/callback", params: { state: state, code: "code" }
    assert_includes response.redirect_url, "invalid_state"
  end
end
