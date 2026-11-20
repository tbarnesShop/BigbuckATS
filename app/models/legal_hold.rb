# frozen_string_literal: true

class LegalHold < ApplicationRecord
  include HasUuid
  include TenantScoped

  SUBJECTS = %w[person application job].freeze

  validates :subject_type, :subject_id, :reason, :placed_by_user_id, :placed_at, presence: true
  validates :subject_type, inclusion: { in: SUBJECTS }

  scope :active, -> { where(released_at: nil) }

  def active?
    released_at.nil?
  end
end
