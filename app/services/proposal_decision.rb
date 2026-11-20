# frozen_string_literal: true

# A person's decision on an agent proposal. Approving enrolls through the normal path (opt-out,
# outreach policy and consent checks all run), so an agent never has a side door to the send queue.
class ProposalDecision
  def self.approve!(proposal, decided_by_user_id:, opener: nil, reason: nil)
    raise ArgumentError, "not_pending" unless proposal.pending?

    final = opener.presence || proposal.draft_opener
    ActiveRecord::Base.transaction do
      enrollment = SequenceRunner.enroll!(
        sequence: proposal.sequence, person: proposal.person, mailbox: proposal.mailbox,
        merge_fields: { "opener" => final.to_s }
      )
      proposal.update!(status: "approved", final_opener: final, decided_by_user_id: decided_by_user_id,
                       decided_at: Time.current, decision_reason: reason, enrollment_id: enrollment.id)
      RediscoveryCandidate.where(id: proposal.rediscovery_candidate_id, status: "pending").update_all(status: "enrolled", updated_at: Time.current)
      SourcingAgent.audit(proposal, "agent_proposal.approved")
    end
    proposal
  end

  def self.reject!(proposal, decided_by_user_id:, reason: nil)
    raise ArgumentError, "not_pending" unless proposal.pending?

    proposal.update!(status: "rejected", decided_by_user_id: decided_by_user_id, decided_at: Time.current, decision_reason: reason)
    RediscoveryCandidate.where(id: proposal.rediscovery_candidate_id, status: "pending").update_all(status: "not_a_fit", feedback: reason, updated_at: Time.current)
    SourcingAgent.audit(proposal, "agent_proposal.rejected")
    proposal
  end
end
