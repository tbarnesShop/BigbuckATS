# frozen_string_literal: true

class ScheduledMessage < ApplicationRecord
  include HasUuid
  include TenantScoped

  STATUSES = %w[queued sent cancelled failed].freeze

  belongs_to :mailbox
  belongs_to :person

  scope :due, -> { where(status: "queued").where("send_at <= ?", Time.current) }
end
