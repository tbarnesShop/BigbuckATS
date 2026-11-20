# frozen_string_literal: true

module V1
  # Read-only roster: who is in the workspace, their organization role, and what each role can do.
  class TeamController < ApplicationController
    before_action :require_tenant!

    def index
      members = Membership.includes(:user, :role).where(status: "active").to_a.select(&:user)
      roles = Role.includes(:role_permissions).order(:name).to_a
      render json: {
        data: members.sort_by { |member| member.user.name.to_s }.map { |member|
          {
            "user_id" => member.user_id,
            "name" => member.user.name,
            "email" => member.user.email,
            "role_key" => member.role&.key,
            "role_name" => member.role&.name,
            "scoped" => !member.org_wide?
          }
        },
        roles: roles.map { |role|
          { "key" => role.key, "name" => role.name, "system" => role.system,
            "permissions" => role.role_permissions.map(&:permission).sort,
            "member_count" => members.count { |member| member.role_id == role.id } }
        }
      }
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end
  end
end
