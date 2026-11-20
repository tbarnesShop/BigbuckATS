# frozen_string_literal: true

# Append-only candidate (or recorded) response. No updates after create.
class OfferResponse < ApplicationRecord
  include HasUuid
  include TenantScoped

  self.record_timestamps = false

  RESPONSES = %w[accepted declined].freeze
  RESPONDED_BY = %w[candidate recorded_by_user].freeze

  belongs_to :offer_version

  validates :response, :responded_by, presence: true
  validates :response, inclusion: { in: RESPONSES }
  validates :responded_by, inclusion: { in: RESPONDED_BY }

  before_destroy { raise ActiveRecord::ReadOnlyRecord, "offer_responses are append-only" }
  before_update { raise ActiveRecord::ReadOnlyRecord, "offer_responses are append-only" }
end
