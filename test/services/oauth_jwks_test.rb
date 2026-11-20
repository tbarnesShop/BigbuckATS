require "test_helper"

class OauthJwksTest < ActiveSupport::TestCase
  setup do
    @prior = ENV.to_hash.slice("BIGBUCK_OAUTH_ISSUER", "BIGBUCK_OAUTH_JWKS_URI")
    ENV["BIGBUCK_OAUTH_ISSUER"] = "https://identity.example.test/"
    ENV["BIGBUCK_OAUTH_JWKS_URI"] = "https://identity.example.test/keys"
    @key = JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048), "key-1")
    OauthAccessToken.reset_keys!
  end

  teardown do
    %w[BIGBUCK_OAUTH_ISSUER BIGBUCK_OAUTH_JWKS_URI].each { |name| @prior.key?(name) ? ENV[name] = @prior[name] : ENV.delete(name) }
    OauthAccessToken.reset_keys!
  end

  # A fake HTTP transport exercises the actual key parser and cache. It does
  # not bypass signature validation in the API integration tests.
  def transport(body, code: "200")
    requests = []
    response = code == "200" ? Net::HTTPOK.new("1.1", code, "OK") : Net::HTTPFound.new("1.1", code, "Redirect")
    response.define_singleton_method(:read_body) { |&block| block.call(body) }
    http = Object.new
    http.define_singleton_method(:request) { |request, &block| requests << request; block.call(response) }
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) { |*args, **opts, &block| block.call(http) }
    yield requests
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end

  test "trusted keys cache and rate-limit unknown key refreshes" do
    transport({ keys: [ @key.export ] }.to_json) do |requests|
      keys = OauthAccessToken.send(:keys, {})
      assert_equal "key-1", keys.first[:kid]
      OauthAccessToken.send(:keys, kid_not_found: true)
      assert_equal 1, requests.size
      OauthAccessToken.instance_variable_get(:@cache)[:at] -= 31
      OauthAccessToken.instance_variable_get(:@last_attempt)[:at] -= 31
      OauthAccessToken.send(:keys, kid_not_found: true)
      assert_equal 2, requests.size
      OauthAccessToken.instance_variable_get(:@cache)[:at] -= 301
      OauthAccessToken.instance_variable_get(:@last_attempt)[:at] -= 301
      OauthAccessToken.send(:keys, {})
      assert_equal 3, requests.size
    end
  end

  test "rejects malformed unsafe weak or redirected key sets" do
    weak = JWT::JWK.new(OpenSSL::PKey::RSA.generate(1024), "weak").export
    bodies = [ "not-json", "[]", { keys: [] }.to_json, { keys: [ { kty: "RSA", kid: "broken" } ] }.to_json,
      { keys: [ weak ] }.to_json, { keys: [ @key.export.merge(use: "enc") ] }.to_json, "x" * (OauthAccessToken::MAX_JWKS_BYTES + 1) ]
    bodies.each do |body|
      transport(body) { assert_raises(Authenticator::Unauthenticated) { OauthAccessToken.send(:fetch_keys) } }
    end
    transport({ keys: [ @key.export ] }.to_json, code: "302") do
      assert_raises(Authenticator::Unauthenticated) { OauthAccessToken.send(:fetch_keys) }
    end
    ENV["BIGBUCK_OAUTH_JWKS_URI"] = "http://attacker.test/keys"
    assert_raises(Authenticator::Unauthenticated) { OauthAccessToken.send(:fetch_keys) }
  end

  test "provider failures are throttled and stale keys fail closed" do
    transport({ keys: [ @key.export ] }.to_json) { OauthAccessToken.send(:keys, {}) }
    OauthAccessToken.instance_variable_get(:@cache)[:at] -= 301
    OauthAccessToken.instance_variable_get(:@last_attempt)[:at] -= 301
    transport("unavailable", code: "302") do |requests|
      3.times { assert_raises(Authenticator::Unauthenticated) { OauthAccessToken.send(:keys, {}) } }
      assert_equal 1, requests.size
    end
  end
end
