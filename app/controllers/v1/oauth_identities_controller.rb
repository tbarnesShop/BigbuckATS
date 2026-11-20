# frozen_string_literal: true

module V1
  class OauthIdentitiesController < ApplicationController
    include IdentityHelpers
    before_action :forbid_agents!

    def index
      render json: { data: OauthIdentity.order(:created_at).limit(200).map { |identity| serialize(identity) } }
    end

    def create
      return render_problem(status: :service_unavailable, code: "oauth_not_configured", title: "Configure the OAuth issuer, audience and JWKS URL first.") unless OauthAccessToken.configured?
      identity = OauthIdentity.new(params.require(:oauth_identity).permit(:name, :subject, :client_id, :kind, :membership_id, scopes: []))
      identity.issuer = OauthAccessToken.issuer
      ChangeWriter.call(record: identity, action: "oauth_identity.created", event_type: nil)
      render json: serialize(identity), status: :created
    end

    def revoke
      identity = OauthIdentity.find(params[:id])
      identity.assign_attributes(status: "revoked", revoked_at: Time.current)
      ChangeWriter.call(record: identity, action: "oauth_identity.revoked", event_type: nil)
      render json: serialize(identity)
    end

    private

    def serialize(identity)
      identity.as_json(only: %i[id name issuer subject client_id kind membership_id scopes status revoked_at created_at])
    end
  end
end
