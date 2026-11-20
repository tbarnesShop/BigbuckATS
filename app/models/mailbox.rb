# frozen_string_literal: true

class Mailbox < ApplicationRecord
  include HasUuid
  include TenantScoped

  KINDS = %w[personal shared].freeze
  STATUSES = %w[pending connected paused disconnected].freeze
  PROVIDERS = MailTransport::PROVIDERS

  belongs_to :user, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :provider, inclusion: { in: PROVIDERS }
  validates :email, presence: true, uniqueness: { scope: :organization_id }

  def sandbox?
    provider == "sandbox"
  end

  def reserve_send!
    today = Time.zone.today
    reload
    if daily_send_on != today
      update!(daily_send_on: today, daily_send_count: 0)
    end
    raise ArgumentError, "mailbox_not_connected" unless status == "connected"
    raise ArgumentError, "mailbox_cap_reached" if daily_send_count >= daily_cap

    update!(daily_send_count: daily_send_count + 1)
  end
end
