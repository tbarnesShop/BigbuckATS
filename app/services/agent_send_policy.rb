# frozen_string_literal: true

# What an agent may do without a person approving it. Default: nothing - every agent enrollment
# waits as a proposal. An org owner can opt in to "unattended".
class AgentSendPolicy
  VALUES = %w[approval_required unattended].freeze
  DEFAULT = "approval_required"

  def self.for(organization)
    value = organization.setting("agent_send_policy", DEFAULT)
    VALUES.include?(value) ? value : DEFAULT
  end

  def self.approval_required?(organization) = self.for(organization) != "unattended"
end
