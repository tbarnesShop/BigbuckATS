# frozen_string_literal: true

class RetentionAction < ApplicationRecord
  include HasUuid
  include TenantScoped

  self.record_timestamps = false

  ACTIONS = %w[
    extension_requested extended review_queued review_kept
    anonymized deleted erased held
  ].freeze

  belongs_to :person

  validates :action, :created_at, presence: true
  validates :action, inclusion: { in: ACTIONS }

  before_destroy { raise ActiveRecord::ReadOnlyRecord, "retention_actions are append-only" }
  before_update { raise ActiveRecord::ReadOnlyRecord, "retention_actions are append-only" }
end
