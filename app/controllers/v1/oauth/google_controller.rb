# frozen_string_literal: true

module V1
  module Oauth
    # Starts and finishes Google sign-in, then sends the browser back to the Remix app.
    class GoogleController < ApplicationController
    rate_limit to: 30, within: 1.minute, by: -> { request.remote_ip }, name: "public-sign-in"
      include ActionController::Cookies
      rescue_from GoogleOauth::NotConfigured do |error|
        render_problem(status: :service_unavailable, code: "google_oauth_not_configured", title: error.message)
      end
      rescue_from GoogleOauth::ExchangeFailed do |error|
        redirect_to_web(error: error.message)
      end
      rescue_from GoogleSignIn::DomainNotVerified do |error|
        redirect_to_web(error: "domain_not_verified:#{error.message}")
      end
      rescue_from ArgumentError do |error|
        redirect_to_web(error: error.message)
      end
      rescue_from ActiveRecord::RecordNotFound do |error|
        redirect_to_web(error: "not_found")
      end

      def start
        raise GoogleOauth::NotConfigured, "google_oauth_not_configured" unless GoogleOauth.configured?
        org = resolve_organization!
        OauthTransaction.where("expires_at < ?", Time.current).limit(1000).delete_all
        state = SecureRandom.urlsafe_base64(32)
        browser = SecureRandom.urlsafe_base64(32)
        verifier = SecureRandom.urlsafe_base64(48)
        nonce = SecureRandom.urlsafe_base64(32)
        payload = { organization_id: org.id, slug: org.slug, return_to: params[:return_to].presence,
          code_verifier: verifier, nonce: nonce }
        OauthTransaction.create!(state_digest: Digest::SHA256.hexdigest(state), browser_digest: Digest::SHA256.hexdigest(browser),
          payload: transaction_encryptor.encrypt_and_sign(payload), expires_at: 10.minutes.from_now)
        cookies[:bigbuck_google_transaction] = { value: browser, httponly: true, secure: Rails.env.production?,
          same_site: :lax, path: "/v1/oauth/google", expires: 10.minutes.from_now }
        challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
        redirect_to GoogleOauth.authorization_url(state: state, code_challenge: challenge, nonce: nonce), allow_other_host: true
      end

      def callback
        state = consume_transaction!(params.require(:state))
        return redirect_to_web(error: "provider_rejected_login") if params[:error].present?
        org = Organization.find(state.fetch("organization_id"))
        profile = GoogleOauth.exchange_code!(code: params.require(:code), code_verifier: state.fetch("code_verifier"), nonce: state.fetch("nonce"))

        Current.organization_id = org.id
        GoogleSignIn.allow?(email: profile[:email], organization: org)

        user = User.find_by(email: profile[:email]) ||
               User.create!(email: profile[:email], name: profile[:name])
        user.update!(name: profile[:name]) if user.name.blank?
        membership = Membership.find_by(user_id: user.id, organization_id: org.id)
        raise ArgumentError, "no_membership" unless membership

        raise ArgumentError, "no_membership" unless membership.status == "active"

        # Hand the browser a one-time code, never a token or an actor id: the
        # web app trades it server-side at POST /v1/sessions/exchange.
        Current.actor_id = user.id
        Current.actor_type = "user"
        handoff = CredentialIssuer.call(
          kind: "handoff", name: "Google sign-in handoff", user: user,
          expires_at: CredentialIssuer::HANDOFF_TTL.from_now, audit: false
        )
        redirect_to_web(code: handoff.token, slug: org.slug, return_to: state["return_to"])
      end

      def status
        render json: {
          "configured" => GoogleOauth.configured?,
          "scopes" => GoogleOauth::SCOPES,
          "redirect_uri" => GoogleOauth.redirect_uri
        }
      end

      private

      def resolve_organization!
        if params[:organization_id].present?
          Organization.find(params[:organization_id])
        elsif params[:slug].present?
          Organization.find_by!(slug: params[:slug])
        else
          raise ArgumentError, "organization_id_or_slug_required"
        end
      end

      def consume_transaction!(raw)
        browser = cookies[:bigbuck_google_transaction].to_s
        raise ArgumentError, "invalid_state" if browser.blank?
        payload = OauthTransaction.transaction do
          row = OauthTransaction.lock.find_by(state_digest: Digest::SHA256.hexdigest(raw))
          raise ArgumentError, "invalid_state" unless row && row.expires_at > Time.current &&
            ActiveSupport::SecurityUtils.secure_compare(row.browser_digest, Digest::SHA256.hexdigest(browser))
          value = transaction_encryptor.decrypt_and_verify(row.payload)
          row.destroy!
          value
        end
        cookies.delete(:bigbuck_google_transaction, path: "/v1/oauth/google")
        payload.stringify_keys
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        raise ArgumentError, "invalid_state"
      end

      def transaction_encryptor
        ActiveSupport::MessageEncryptor.new(Rails.application.key_generator.generate_key("google-oauth-transaction", 32))
      end

      def redirect_to_web(code: nil, slug: nil, return_to: nil, error: nil)
        path = return_to.presence || "/session"
        path = "/session" unless path.start_with?("/") && !path.start_with?("//") && !path.include?("\\")
        uri = URI.join("#{GoogleOauth.web_origin}/", path.delete_prefix("/"))
        q = {}
        q[:code] = code if code
        q[:slug] = slug if slug
        q[:error] = error if error
        uri.query = URI.encode_www_form(q) if q.any?
        redirect_to uri.to_s, allow_other_host: true
      end
    end
  end
end
