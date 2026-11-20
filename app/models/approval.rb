# frozen_string_literal: true

class Approval < ApplicationRecord
  include HasUuid
  include TenantScoped

  STATUSES = %w[pending approved changes_requested skipped cancelled].freeze

  belongs_to :approval_policy, optional: true
  belongs_to :approval_policy_step, optional: true

  validates :entity_type, :entity_id, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
end
