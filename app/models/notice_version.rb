# frozen_string_literal: true

class NoticeVersion < ApplicationRecord
  include HasUuid
  include TenantScoped

  self.record_timestamps = false

  belongs_to :notice

  validates :version_number, :locale, :body, :body_sha256, presence: true

  before_destroy { raise ActiveRecord::ReadOnlyRecord, "notice_versions are append-only" }
  before_update { raise ActiveRecord::ReadOnlyRecord, "notice_versions are append-only" }
end
