# frozen_string_literal: true

class SchedulingLink < ApplicationRecord
  include HasUuid
  include TenantScoped

  KINDS = %w[self_schedule availability reschedule].freeze

  belongs_to :application
  has_one :availability_request, dependent: :destroy

  validates :kind, :interview_keys, :expires_at, presence: true
  validates :kind, inclusion: { in: KINDS }

  def usable?
    used_at.nil? && revoked_at.nil? && expires_at > Time.current
  end
end
