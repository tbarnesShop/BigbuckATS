# frozen_string_literal: true

class SignatureRequest < ApplicationRecord
  include HasUuid
  include TenantScoped

  STATUSES = %w[sent viewed completed declined voided expired].freeze

  belongs_to :offer_version

  validates :provider, :sent_to_email, :status, :expires_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  def usable?
    status.in?(%w[sent viewed]) && expires_at > Time.current
  end
end
