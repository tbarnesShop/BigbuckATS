# frozen_string_literal: true

module V1
  # Browser sessions. A session is a short-lived bearer credential for one user.
  #
  # POST   /v1/sessions           demo email sign-in (only when config.x.demo_sign_in)
  # POST   /v1/sessions/exchange  trade a one-time OAuth handoff code for a session
  # GET    /v1/sessions/current   who am I (user, agent, permissions)
  # DELETE /v1/sessions/current   sign out (revokes the session credential)
  class SessionsController < ApplicationController
    rate_limit to: 30, within: 1.minute, by: -> { request.remote_ip }, name: "public-sign-in"
    include IdentityHelpers

    rescue_from GoogleSignIn::DomainNotVerified do |error|
      render_problem(status: :forbidden, code: "domain_not_verified", title: error.message)
    end
    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_session", title: error.message)
    end

    def create
      unless Rails.configuration.x.demo_sign_in
        return render_problem(status: :forbidden, code: "demo_sign_in_disabled",
                              title: "Email sign-in is only available on demo deployments. Use Google sign-in.")
      end

      email = params.require(:email).to_s.downcase
      org = if params[:organization_id].present?
              Organization.find(params[:organization_id])
      elsif params[:slug].present?
              Organization.find_by!(slug: params[:slug])
      else
              raise ArgumentError, "organization_id_or_slug_required"
      end

      unless DemoSandbox.for_organization(org.id)
        return render_problem(status: :forbidden, code: "demo_tenant_required", title: "Use a registered disposable demo tenant.")
      end
      Current.organization_id = org.id
      GoogleSignIn.allow?(email: email, organization: org)
      user = User.find_by(email: email) || User.create!(email: email, name: email.split("@").first)
      membership = Membership.find_by(user_id: user.id, organization_id: org.id)
      raise ArgumentError, "no_membership" unless membership&.status == "active"

      Current.actor_id = user.id
      Current.actor_type = "user"
      issued = CredentialIssuer.call(
        kind: "session", name: "Demo sign-in", user: user, created_by: user,
        expires_at: CredentialIssuer::DEMO_SESSION_TTL.from_now
      )

      render json: session_body(org, user, membership, issued), status: :created
    end

    def exchange
      issued = CredentialIssuer.redeem_handoff!(params.require(:code))
      unless issued
        return render_problem(status: :unauthorized, code: "invalid_code", title: "The sign-in code is invalid, expired or already used.")
      end

      user = issued.credential.user
      org = Organization.find(issued.credential.organization_id)
      membership = Membership.find_by!(user_id: user.id, organization_id: org.id)
      render json: session_body(org, user, membership, issued), status: :created
    end

    # Existing memberships for the demo role picker. Never creates a user or a membership.
    def demo_memberships
      unless Rails.configuration.x.demo_sign_in
        return render_problem(status: :forbidden, code: "demo_sign_in_disabled",
                              title: "Email sign-in is only available on demo deployments.")
      end

      slug = params[:slug].presence || "big-buck"
      org = Organization.find_by!(slug: slug)
      unless DemoSandbox.for_organization(org.id)
        return render_problem(status: :forbidden, code: "demo_tenant_required", title: "Use a registered disposable demo tenant.")
      end
      Current.organization_id = org.id
      rows = Membership.includes(:user, :role).where(status: "active").sort_by { |membership| membership.user.email.to_s }
      render json: {
        data: rows.map { |membership|
          {
            "email" => membership.user.email,
            "name" => membership.user.name,
            "role_key" => membership.role.key,
            "role_name" => membership.role.name
          }
        }
      }
    end

    def current
      return render_unauthenticated unless current_principal

      render json: current_principal.as_json
    end

    def destroy
      return render_unauthenticated unless current_principal

      credential = current_principal.credential
      credential.revoke! if credential.kind == "session"
      head :no_content
    end

    private

    def render_unauthenticated
      render_problem(status: :unauthorized, code: "unauthenticated", title: "Send a bearer token: Authorization: Bearer <token>.")
    end

    def session_body(org, user, membership, issued)
      {
        "organization" => { "id" => org.id, "name" => org.name, "slug" => org.slug },
        "user" => { "id" => user.id, "email" => user.email, "name" => user.name },
        "membership" => { "id" => membership.id, "role_id" => membership.role_id },
        "session" => {
          "token" => issued.token,
          "expires_at" => issued.credential.expires_at
        }
      }
    end
  end
end
