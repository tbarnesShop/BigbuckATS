# frozen_string_literal: true

class Consent < ApplicationRecord
  include HasUuid
  include TenantScoped

  self.record_timestamps = false

  STATUSES = %w[granted withdrawn expired].freeze

  belongs_to :person
  belongs_to :consent_purpose
  belongs_to :notice_version, optional: true
  belongs_to :compliance_policy, optional: true

  validates :status, :lawful_basis, :captured_via, :captured_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  before_destroy { raise ActiveRecord::ReadOnlyRecord, "consents are append-only" }
  before_update { raise ActiveRecord::ReadOnlyRecord, "consents are append-only" }

  def self.current_for(person_id:, purpose_id:)
    where(person_id: person_id, consent_purpose_id: purpose_id).order(captured_at: :desc).first
  end

  def granted?
    status == "granted" && (expires_at.nil? || expires_at > Time.current)
  end
end
