# frozen_string_literal: true

module V1
  # What agents propose and what people decide. Agents cannot decide proposals (their own or anyone's).
  class AgentProposalsController < ApplicationController
    include IdentityHelpers
    include PersonScoped

    before_action :require_tenant!
    before_action :forbid_agents!, only: %i[approve reject bulk_approve]

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_proposal", title: error.message)
    end

    def index
      rows = AgentProposal.where(person_id: ResourceVisibility.people.select(:id)).includes(:person, :agent).order(created_at: :desc)
      rows = rows.where(status: params[:status]) if params[:status].present?
      rows = rows.where(job_id: params[:job_id]) if params[:job_id].present?
      render json: { data: rows.limit(200).map { |r| serialize(r) }, meta: { "statuses" => rows.reorder(nil).group(:status).count } }
    end

    def approve
      with_idempotency do
        proposal = find_proposal
        ProposalDecision.approve!(proposal, decided_by_user_id: Current.actor_id, opener: params[:opener], reason: params[:reason])
        render json: serialize(proposal.reload)
      end
    end

    def reject
      with_idempotency do
        proposal = find_proposal
        ProposalDecision.reject!(proposal, decided_by_user_id: Current.actor_id, reason: params[:reason])
        render json: serialize(proposal.reload)
      end
    end

    # Approve several at once with their drafted openers. Each is attempted on its own.
    def bulk_approve
      with_idempotency do
        ids = Array(params[:ids]).first(100)
        raise ArgumentError, "ids_required" if ids.empty?

        results = ids.map do |id|
          proposal = AgentProposal.where(person_id: ResourceVisibility.people.select(:id)).find(id)
          ProposalDecision.approve!(proposal, decided_by_user_id: Current.actor_id)
          { "id" => id, "ok" => true, "enrollment_id" => proposal.enrollment_id }
        rescue StandardError => e
          { "id" => id, "ok" => false, "error" => e.message }
        end
        render json: { "approved" => results.count { |r| r["ok"] }, "failed" => results.count { |r| !r["ok"] }, "results" => results }
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def find_proposal
      AgentProposal.where(person_id: ResourceVisibility.people.select(:id)).find(params[:id])
    end

    def serialize(row)
      row.as_json(only: %i[id agent_id on_behalf_of_user_id kind job_id person_id sequence_id mailbox_id status draft_opener final_opener
                           rationale decided_by_user_id decided_at decision_reason enrollment_id created_at])
         .merge("person" => ResourceSummary.person(row.person, fields: %i[id display_name primary_email lifecycle_stage]),
                "agent" => { "id" => row.agent_id, "name" => row.agent&.name })
    end
  end
end
