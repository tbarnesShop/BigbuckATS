# frozen_string_literal: true

class RolePermission < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :role

  validates :permission, presence: true
  validates :permission, uniqueness: { scope: %i[organization_id role_id] }
end
