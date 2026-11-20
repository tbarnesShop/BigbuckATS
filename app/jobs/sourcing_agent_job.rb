# frozen_string_literal: true

# Nightly: for each org that named a sourcing agent and sequence, run the agent over every open job
# that has criteria. Proposals wait for approval unless the org allowed unattended sends.
class SourcingAgentJob < ApplicationJob
  queue_as :sequences

  def perform
    Organization.find_each do |org|
      agent_id = org.setting("sourcing_agent_id")
      sequence_id = org.setting("sourcing_agent_sequence_id")
      next if agent_id.blank? || sequence_id.blank?

      Current.set(organization_id: org.id, source_surface: "automation") { run_org(agent_id, sequence_id) }
    end
  end

  private

  def run_org(agent_id, sequence_id)
    agent = Agent.find_by(id: agent_id)
    sequence = Sequence.find_by(id: sequence_id)
    return unless agent&.active? && sequence

    mailbox = Mailbox.where(user_id: agent.owner_user_id).order(:created_at).first
    viewer = Membership.find_by(id: agent.owner_membership_id)
    return unless mailbox && viewer

    Job.where(status: "active").where.not(criteria: nil).find_each do |job|
      next if Array(job.criteria).empty?

      Current.set(actor_id: agent.owner_user_id, agent_id: agent.id, actor_type: "agent") do
        SourcingAgent.run!(agent: agent, job: job, sequence: sequence, mailbox: mailbox, viewer: viewer)
      rescue StandardError => e
        Rails.logger.error({ event: "sourcing_agent.failed", job_id: job.id, error: e.class.name, message: e.message }.to_json)
      end
    end
  end
end
