# frozen_string_literal: true

# Explicit provider subject/client binding. Provider email and tenant claims
# never provision membership or select an organization.
class OauthIdentity < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :membership, optional: true
  validates :name, :issuer, :subject, :client_id, presence: true, length: { maximum: 255 }
  validates :kind, inclusion: { in: %w[human service] }
  validates :status, inclusion: { in: %w[active revoked] }
  validates :binding_digest, uniqueness: true
  validate :identity_shape
  validate :known_scopes
  before_validation :assign_binding_digest
  attr_readonly :issuer, :subject, :client_id, :kind, :membership_id, :organization_id, :binding_digest

  def self.digest(issuer, subject, client_id)
    Digest::SHA256.hexdigest([ issuer, subject, client_id ].to_json)
  end

  def active?
    status == "active" && revoked_at.nil?
  end

  private

  def assign_binding_digest
    self.binding_digest = self.class.digest(issuer, subject, client_id) if new_record?
    self.scopes = Array(scopes).map(&:to_s).uniq.sort
  end

  def identity_shape
    errors.add(:membership, "required for a human identity") if kind == "human" && membership.nil?
    errors.add(:membership, "not allowed for a service identity") if kind == "service" && membership.present?
    errors.add(:membership, "must belong to this organization") if membership && membership.organization_id != organization_id
    errors.add(:issuer, "must match the configured issuer") unless issuer == OauthAccessToken.issuer
  end

  def known_scopes
    errors.add(:scopes, "must not be empty") if Array(scopes).empty?
    errors.add(:scopes, "contains unknown scopes") if Scopes.unknown(scopes).any?
  end
end
