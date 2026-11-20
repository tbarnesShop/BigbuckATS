# frozen_string_literal: true

# A bearer credential. Only a SHA-256 digest of the token is stored; tokens are
# 40 random base62 characters, so a plain digest is safe for lookup.
#
# kinds:
#   personal    - acts for user_id, scopes ∩ user's role
#   integration - acts for the org (no user), exactly its scopes
#   agent       - acts as agent_id for its owner, agent scopes ∩ owner's role
#   session     - browser sign-in for user_id, full role, short-lived
#   handoff     - one-time code exchanged for a session after OAuth; never a bearer
class ApiCredential < ApplicationRecord
  include HasUuid
  include TenantScoped

  KINDS = %w[personal integration agent session handoff].freeze
  BEARER_KINDS = %w[personal integration agent session].freeze
  CURRENT_API_VERSION = "2026-11-01"
  TOKEN_PATTERN = /\Abb_(live|test|sess|hand)_[0-9A-Za-z]{40}\z/
  LAST_USED_RESOLUTION = 5.minutes

  belongs_to :user, optional: true
  belongs_to :agent, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :name, :token_prefix, :token_digest, :status, presence: true
  validate :kind_shape
  validate :scopes_are_known

  before_validation { self.scopes = Array(scopes).map(&:to_s).uniq.sort }

  scope :active, -> { where(status: "active") }

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  # Platform lookup across tenants by token digest. Returns nil for unknown,
  # revoked, used, expired or non-bearer tokens.
  def self.find_bearer(token)
    return nil unless token.to_s.match?(TOKEN_PATTERN)

    credential = unscoped.find_by(token_digest: digest(token))
    return nil unless credential&.usable?
    return nil unless BEARER_KINDS.include?(credential.kind)

    credential
  end

  def usable?
    status == "active" && revoked_at.nil? && (expires_at.nil? || expires_at.future?)
  end

  def revoke!
    update!(status: "revoked", revoked_at: Time.current, version: version + 1)
  end

  def touch_last_used!
    return if last_used_at && last_used_at > LAST_USED_RESOLUTION.ago

    update_columns(last_used_at: Time.current)
  end

  private

  def kind_shape
    case kind
    when "personal", "session", "handoff"
      errors.add(:user_id, "required for #{kind} credentials") if user_id.blank?
      errors.add(:agent_id, "not allowed for #{kind} credentials") if agent_id.present?
    when "agent"
      errors.add(:agent_id, "required for agent credentials") if agent_id.blank?
    when "integration"
      errors.add(:user_id, "not allowed for integration credentials") if user_id.present?
      errors.add(:scopes, "must not be empty") if Array(scopes).empty?
    end
  end

  def scopes_are_known
    unknown = Scopes.unknown(scopes)
    errors.add(:scopes, "unknown: #{unknown.join(', ')}") if unknown.any?
  end
end
