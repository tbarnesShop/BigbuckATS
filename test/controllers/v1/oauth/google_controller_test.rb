# frozen_string_literal: true

require "test_helper"

module V1
  module Oauth
    class GoogleControllerTest < ActionDispatch::IntegrationTest
      setup do
        @prev = ENV.to_hash.slice(
          "GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET", "GOOGLE_REDIRECT_URI", "WEB_ORIGIN"
        )
        ENV.delete("GOOGLE_CLIENT_ID")
        ENV.delete("GOOGLE_CLIENT_SECRET")
        ENV.delete("GOOGLE_REDIRECT_URI")
        ENV["WEB_ORIGIN"] = "https://app.example.com"

        @dataset = BigBuckDataset.call(slug: "big-buck-oauth-#{SecureRandom.hex(3)}")
        @org = @dataset.organization
        Current.reset
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

      test "status reports not configured" do
        get "/v1/oauth/google/status"
        assert_response :success
        body = JSON.parse(response.body)
        assert_equal false, body["configured"]
      end

      test "start fails closed when oauth is not configured" do
        get "/v1/oauth/google", params: { slug: @org.slug }
        assert_response :service_unavailable
        body = JSON.parse(response.body)
        assert_equal "google_oauth_not_configured", body["code"]
      end

      test "start redirects to google when configured" do
        ENV["GOOGLE_CLIENT_ID"] = "client.apps.googleusercontent.com"
        ENV["GOOGLE_CLIENT_SECRET"] = "secret"
        ENV["GOOGLE_REDIRECT_URI"] = "https://api.example.com/v1/oauth/google/callback"

        get "/v1/oauth/google", params: { slug: @org.slug }
        assert_response :redirect
        assert_match %r{\Ahttps://accounts\.google\.com/}, response.redirect_url
      end
    end
  end
end
