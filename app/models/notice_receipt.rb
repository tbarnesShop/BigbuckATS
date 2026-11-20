# frozen_string_literal: true

class NoticeReceipt < ApplicationRecord
  include HasUuid
  include TenantScoped

  self.record_timestamps = false

  belongs_to :person
  belongs_to :notice_version

  validates :shown_via, :locale, :shown_at, presence: true

  before_destroy { raise ActiveRecord::ReadOnlyRecord, "notice_receipts are append-only" }
  before_update { raise ActiveRecord::ReadOnlyRecord, "notice_receipts are append-only" }
end
