# frozen_string_literal: true

# The sourcing agent's loop for one job: refresh the rediscovery queue from the job's criteria, then
# turn the best waiting people into enrollment proposals with a drafted opener. People who could not
# be contacted today (opted out, cooldown, already enrolled...) are not proposed.
class SourcingAgent
  Result = Struct.new(:rediscovery, :proposed, :auto_enrolled, :skipped, keyword_init: true)

  def self.run!(agent:, job:, sequence:, mailbox:, viewer:, limit: 10)
    raise ArgumentError, "agent_inactive" unless agent.active?
    raise ArgumentError, "criteria_required" if Array(job.criteria).empty?

    discovery = RediscoveryEngine.run!(job: job, viewer: viewer, found_by_agent_id: agent.id)
    rows = RediscoveryCandidate.where(job_id: job.id, status: "pending").includes(:person).order(score: :desc).limit(limit * 3).to_a
    already = AgentProposal.where(sequence_id: sequence.id, status: %w[pending approved]).pluck(:person_id).to_set
    skipped = Hash.new(0)
    proposed = []
    auto = 0

    rows.each do |row|
      break if proposed.size + auto >= limit
      next skipped["already_proposed"] += 1 if already.include?(row.person_id)

      reason = EnrollmentPlanner.skip_reason(row.person)
      next skipped[reason] += 1 if reason

      proposal = AgentProposal.create!(
        agent: agent, on_behalf_of_user_id: agent.owner_user_id, job_id: job.id, person: row.person, sequence: sequence,
        mailbox: mailbox, rediscovery_candidate_id: row.id, status: "pending",
        draft_opener: OpenerDrafter.draft(person: row.person, job: job, verdicts: row.verdicts, bucket: row.bucket),
        rationale: { "bucket" => row.bucket, "score" => row.score, "reasons" => row.reasons, "verdicts" => row.verdicts }
      )
      audit(proposal, "agent_proposal.created")
      if AgentSendPolicy.approval_required?(Organization.find(Current.organization_id))
        proposed << proposal
      else
        ProposalDecision.approve!(proposal, decided_by_user_id: nil, reason: "org policy: unattended")
        auto += 1
      end
    end
    Result.new(rediscovery: discovery, proposed: proposed, auto_enrolled: auto, skipped: skipped)
  end

  def self.audit(proposal, action)
    ChangeWriter.call(
      record: proposal, action: action, event_type: action,
      payload: { "agent_id" => proposal.agent_id, "person_id" => proposal.person_id, "sequence_id" => proposal.sequence_id, "job_id" => proposal.job_id }
    )
  end
end
