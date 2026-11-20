# frozen_string_literal: true

# Big Buck's own notifications to users (never candidates). The provider is an
# open decision (research/decisions.md); until it is chosen, notifications are
# structured log lines that a log-based alert or a later provider can consume.
module Notifier
  module_function

  def notify(kind:, user_id:, organization_id:, data: {})
    Rails.logger.info({ event: "notify", kind: kind, user_id: user_id, organization_id: organization_id, data: data }.to_json)
  end
end
