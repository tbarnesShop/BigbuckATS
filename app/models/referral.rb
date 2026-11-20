# frozen_string_literal: true

class Referral < ApplicationRecord
  include HasUuid
  include TenantScoped

  STATUSES = %w[submitted converted hired withdrawn].freeze

  belongs_to :person
  belongs_to :job, optional: true
  belongs_to :application, optional: true
  belongs_to :referrer, class_name: "User", foreign_key: :referrer_user_id

  validates :referrer_user_id, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
end
