# frozen_string_literal: true

class Interview < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :application
  has_many :scorecards, dependent: :destroy

  validates :stage_key, :interview_key, :status, presence: true

  # Interviews that can take feedback now: finished, or booked and already started. One that is still
  # in the future owes nobody a scorecard yet.
  scope :feedback_open, lambda {
    where(status: "completed").or(where(status: "scheduled").where(starts_at: ..Time.current))
  }
end
