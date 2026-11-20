# frozen_string_literal: true

class BreakGlassSession < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :opened_by_user_id, :reason, :opens_at, :expires_at, :status, presence: true

  def open?
    status == "open" && closed_at.nil? && expires_at > Time.current
  end
end
