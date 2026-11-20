# frozen_string_literal: true

class CalendarWatchChannel < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :calendar_connection

  validates :calendar_id, :channel_id, :expires_at, presence: true
end
