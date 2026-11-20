# frozen_string_literal: true

class Role < ApplicationRecord
  include HasUuid
  include TenantScoped

  has_many :role_permissions, dependent: :destroy
  has_many :memberships, dependent: :restrict_with_exception

  validates :key, :name, presence: true
  validates :key, uniqueness: { scope: :organization_id }

  def permissions
    role_permissions.pluck(:permission)
  end

  def grant!(*perms)
    perms.flatten.each do |permission|
      role_permissions.find_or_create_by!(permission: permission) do |rp|
        rp.organization_id = organization_id
      end
    end
  end
end
