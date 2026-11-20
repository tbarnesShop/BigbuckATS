# frozen_string_literal: true

module V1
  # Agents: first-class principals owned by a membership. Members manage their
  # own agents (agent.manage_own); agent.manage covers everyone's. Agents cannot
  # manage agents. An agent's effective permissions are its scopes ∩ its owner's
  # role, so it can never do more than its owner.
  class AgentsController < ApplicationController
    include IdentityHelpers

    before_action :forbid_agents!, except: %i[index show]

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: error.message, title: error.message.humanize)
    end

    def index
      rows = visible_agents.order(:created_at).limit(200)
      render json: { data: rows.map { |a| serialize_agent(a) } }
    end

    def show
      render json: serialize_agent(find_visible!(params[:id]))
    end

    def create
      with_idempotency do
        owner = owner_for_create!
        agent = Agent.new(
          owner_membership_id: owner.id,
          name: agent_params.require(:name),
          description: agent_params[:description],
          scopes: Array(params.dig(:agent, :scopes)),
          created_by_user_id: Current.actor_id
        )
        ChangeWriter.call(
          record: agent, action: "agent.created", event_type: "agent.created",
          payload: { "name" => agent.name, "owner_membership_id" => owner.id, "scopes" => agent.scopes }
        )
        render json: serialize_agent(agent), status: :created
      end
    end

    def pause
      change_status!("paused", "agent.paused") { |a| a.paused_at = Time.current }
    end

    def resume
      change_status!("active", "agent.resumed") { |a| a.paused_at = nil }
    end

    def revoke
      agent = find_manageable!(params[:id])
      Agent.transaction do
        agent.api_credentials.active.find_each(&:revoke!)
        agent.assign_attributes(status: "revoked", revoked_at: Time.current, version: agent.version + 1)
        ChangeWriter.call(record: agent, action: "agent.revoked", event_type: "agent.revoked", payload: {})
      end
      render json: serialize_agent(agent)
    end

    # Issues a bearer token for the agent. The token is shown once.
    def create_credential
      agent = find_manageable!(params[:id])
      raise ArgumentError, "agent_revoked" if agent.status == "revoked"

      issued = CredentialIssuer.call(
        kind: "agent", name: params[:name].presence || "#{agent.name} token", agent: agent,
        expires_at: parse_expires_at(params[:expires_at]), created_by: acting_user
      )
      render json: serialize_credential(issued.credential, token: issued.token), status: :created
    end

    private

    def agent_params
      params.require(:agent).permit(:name, :description, :owner_membership_id, scopes: [])
    end

    def acting_user
      acting_membership&.user
    end

    def manage_all?
      permitted?("agent.manage")
    end

    def visible_agents
      return Agent.all if manage_all?

      membership = acting_membership
      membership ? Agent.where(owner_membership_id: membership.id) : Agent.none
    end

    def find_visible!(id)
      visible_agents.find(id)
    end

    def find_manageable!(id)
      agent = find_visible!(id)
      require_permission!("agent.manage_own") unless manage_all?
      agent
    end

    def owner_for_create!
      requested = agent_params[:owner_membership_id].presence
      membership = require_membership!
      return membership if requested.nil? || requested == membership.id

      require_permission!("agent.manage")
      Membership.find(requested)
    end

    def change_status!(status, action)
      agent = find_manageable!(params[:id])
      raise ArgumentError, "agent_revoked" if agent.status == "revoked"

      agent.status = status
      yield agent
      agent.version += 1
      ChangeWriter.call(record: agent, action: action, event_type: action, payload: { "status" => status })
      render json: serialize_agent(agent)
    end
  end
end
