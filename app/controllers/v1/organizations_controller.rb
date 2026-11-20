# frozen_string_literal: true

module V1
  class OrganizationsController < ApplicationController
    before_action :require_tenant!, only: %i[update]
    before_action :require_bootstrap_token!, only: %i[create]

    def create
      with_idempotency do
        result = OrganizationProvisioner.call(
          name: org_params[:name],
          slug: org_params[:slug],
          owner_email: org_params[:owner_email],
          owner_name: org_params[:owner_name]
        )
        render json: {
          id: result[:organization].id,
          name: result[:organization].name,
          slug: result[:organization].slug,
          owner_user_id: result[:user].id,
          membership_id: result[:membership].id
        }, status: :created
      end
    end

    def update
      org = Organization.find(params[:id])
      raise ActiveRecord::RecordNotFound unless org.id == Current.organization_id

      attrs = settings_params.to_h
      accent = attrs["careers_accent_color"]
      if accent.present? && !accent.match?(Organization::ACCENT_COLOR)
        return render_problem(status: :unprocessable_entity, code: "invalid_accent_color",
                              title: "careers_accent_color must be a #RRGGBB hex color.")
      end
      if attrs.key?("careers_culture")
        attrs["careers_culture"] = Array(attrs["careers_culture"]).map { |b| { "title" => b["title"].to_s, "body" => b["body"].to_s } }
      end
      if attrs.key?("agent_send_policy") && !AgentSendPolicy::VALUES.include?(attrs["agent_send_policy"])
        return render_problem(status: :unprocessable_entity, code: "invalid_agent_send_policy",
                              title: "agent_send_policy must be #{AgentSendPolicy::VALUES.join(' or ')}.")
      end
      org.merge_settings!(attrs) if attrs.present?
      render json: serialize(org)
    end

    private

    # Creating organizations is a platform operation. Outside development and
    # test it needs X-Bigbuck-Bootstrap-Token matching BIGBUCK_BOOTSTRAP_TOKEN.
    def require_bootstrap_token!
      return unless Rails.env.production?

      expected = ENV["BIGBUCK_BOOTSTRAP_TOKEN"].to_s
      given = request.headers["X-Bigbuck-Bootstrap-Token"].to_s
      return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, given)

      render_problem(status: :forbidden, code: "bootstrap_token_required",
                     title: "Creating an organization needs the platform bootstrap token.")
    end

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def org_params
      params.require(:organization).permit(:name, :slug, :owner_email, :owner_name)
    end

    def settings_params
      params.fetch(:organization, {}).permit(
        :careers_hero_image_url,
        :careers_headline,
        :careers_subcopy,
        :careers_about_title,
        :careers_about_body,
        :careers_culture_title,
        :careers_culture_body,
        :careers_accent_color,
        :contact_cooldown_days,
        :agent_send_policy,
        :sourcing_agent_id,
        :sourcing_agent_sequence_id,
        careers_culture: %i[title body]
      )
    end

    def serialize(org)
      {
        "id" => org.id,
        "name" => org.name,
        "slug" => org.slug,
        "contact_cooldown_days" => org.contact_cooldown_days,
        "agent_send_policy" => AgentSendPolicy.for(org),
        "sourcing_agent_id" => org.setting("sourcing_agent_id"),
        "sourcing_agent_sequence_id" => org.setting("sourcing_agent_sequence_id"),
        "careers" => {
          "hero_image_url" => org.careers_hero_image_url,
          "headline" => org.careers_headline,
          "subcopy" => org.careers_subcopy,
          "about" => org.careers_section("about"),
          "culture_intro" => org.careers_section("culture"),
          "culture" => org.setting("careers_culture"),
          "accent_color" => org.careers_accent_color
        }
      }
    end
  end
end
