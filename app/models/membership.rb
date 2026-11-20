# frozen_string_literal: true

class Membership < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :user
  belongs_to :role
  has_many :membership_scopes, dependent: :destroy

  validates :user_id, uniqueness: { scope: :organization_id }
  validates :status, presence: true

  def permission?(name)
    role.permissions.include?(name.to_s)
  end

  def interviewer_user_id = user_id

  def org_wide?
    membership_scopes.empty?
  end
end
