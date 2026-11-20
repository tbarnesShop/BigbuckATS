# frozen_string_literal: true

# One rediscovered person in a job's review queue, with the per-criterion verdicts that put them there.
class RediscoveryCandidate < ApplicationRecord
  include HasUuid
  include TenantScoped

  STATUSES = %w[pending considering added_to_pool enrolled not_a_fit review_later].freeze
  BUCKETS = %w[silver_medalist high_fit internal_transfer warm_lead].freeze
  ACTIONS = { "consider" => "considering", "add_to_pool" => "added_to_pool", "enroll" => "enrolled",
              "not_a_fit" => "not_a_fit", "review_later" => "review_later" }.freeze

  belongs_to :job
  belongs_to :person

  validates :status, inclusion: { in: STATUSES }
  validates :bucket, inclusion: { in: BUCKETS }
  # Decisions made by a person stick: a later run refreshes only people still waiting for review.
  def decided? = !%w[pending].include?(status)
end
