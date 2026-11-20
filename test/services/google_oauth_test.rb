# frozen_string_literal: true

require "test_helper"

class GoogleOauthTest < ActiveSupport::TestCase
  setup do
    @prev = ENV.to_hash.slice("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET", "GOOGLE_REDIRECT_URI", "WEB_ORIGIN")
    ENV["GOOGLE_CLIENT_ID"] = "client.apps.googleusercontent.com"
    ENV["GOOGLE_CLIENT_SECRET"] = "secret"
    ENV["GOOGLE_REDIRECT_URI"] = "https://api.example.com/v1/oauth/google/callback"
    ENV["WEB_ORIGIN"] = "https://app.example.com"
  end

  teardown do
    %w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_REDIRECT_URI WEB_ORIGIN].each do |key|
      if @prev[key]
        ENV[key] = @prev[key]
      else
        ENV.delete(key)
      end
    end
  end

  test "configured when client credentials and redirect are set" do
    assert GoogleOauth.configured?
    url = GoogleOauth.authorization_url(state: "abc")
    assert_includes url, "accounts.google.com"
    assert_includes url, "client_id=client.apps.googleusercontent.com"
    assert_includes url, "state=abc"
  end

  test "not configured without secrets" do
    ENV.delete("GOOGLE_CLIENT_SECRET")
    assert_not GoogleOauth.configured?
    assert_raises(GoogleOauth::NotConfigured) do
      GoogleOauth.authorization_url(state: "x")
    end
  end
end
