# frozen_string_literal: true

module V1
  # Runs the sourcing loop for one job as the calling agent (or, for a person, as one of their agents).
  class SourcingAgentController < ApplicationController
    include PersonScoped

    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_sourcing_run", title: error.message)
    end

    def run
      with_idempotency do
        job = ResourceVisibility.jobs.find(params[:job_id])
        agent = acting_agent
        sequence = Sequence.find(params.require(:sequence_id))
        mailbox = params[:mailbox_id].present? ? Mailbox.find(params[:mailbox_id]) : Mailbox.where(user_id: agent.owner_user_id).order(:created_at).first || raise(ArgumentError, "mailbox_required")
        limit = [ [ (params[:limit] || 10).to_i, 1 ].max, 50 ].min
        result = Current.set(agent_id: agent.id, actor_type: "agent") do
          SourcingAgent.run!(agent: agent, job: job, sequence: sequence, mailbox: mailbox, viewer: viewer, limit: limit)
        end
        render json: {
          "agent_id" => agent.id, "job_id" => job.id, "policy" => AgentSendPolicy.for(Organization.find(Current.organization_id)),
          "rediscovery" => { "created" => result.rediscovery.created, "refreshed" => result.rediscovery.refreshed, "buckets" => result.rediscovery.buckets },
          "proposed" => result.proposed.map(&:id), "auto_enrolled" => result.auto_enrolled, "skipped" => result.skipped
        }
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def acting_agent
      return current_principal.agent if current_principal&.agent

      scope = Agent.where(owner_membership_id: Membership.where(user_id: Current.actor_id).select(:id))
      params[:agent_id].present? ? scope.find(params[:agent_id]) : scope.where(status: "active").order(:created_at).first || raise(ArgumentError, "agent_required")
    end
  end
end
