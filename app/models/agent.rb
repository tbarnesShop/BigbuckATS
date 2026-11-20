# frozen_string_literal: true

# An agent is a first-class principal owned by one membership. It acts with the
# owner's role intersected with its own scopes, and audit records it as the
# actor with the owner as on_behalf_of.
class Agent < ApplicationRecord
  include HasUuid
  include TenantScoped

  STATUSES = %w[active paused revoked].freeze

  belongs_to :owner_membership, class_name: "Membership"
  has_many :api_credentials, dependent: :restrict_with_exception

  validates :name, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :name, uniqueness: { scope: %i[organization_id owner_membership_id] }
  validate :scopes_are_known

  before_validation { self.scopes = Array(scopes).map(&:to_s).uniq.sort }

  def active?
    status == "active" && owner_membership&.status == "active"
  end

  def owner_user_id
    owner_membership&.user_id
  end

  private

  def scopes_are_known
    unknown = Scopes.unknown(scopes)
    errors.add(:scopes, "unknown: #{unknown.join(', ')}") if unknown.any?
    errors.add(:scopes, "must not be empty") if Array(scopes).empty?
  end
end
