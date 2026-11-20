# frozen_string_literal: true

class DataRequest < ApplicationRecord
  include HasUuid
  include TenantScoped

  KINDS = %w[access correction erasure].freeze
  STATUSES = %w[open completed rejected].freeze

  belongs_to :person, optional: true

  validates :kind, :received_at, :due_at, :status, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
end
