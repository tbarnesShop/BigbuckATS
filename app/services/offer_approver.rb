# frozen_string_literal: true

# Approve or request changes on a pending approval; advances steps when complete.
class OfferApprover
  def self.approve!(approval:, actor_id: Current.actor_id, override: false)
    new(approval: approval, actor_id: actor_id, override: override).approve!
  end

  def self.request_changes!(approval:, reason:, actor_id: Current.actor_id)
    new(approval: approval, actor_id: actor_id).request_changes!(reason: reason)
  end

  def initialize(approval:, actor_id:, override: false)
    @approval = approval
    @actor_id = actor_id
    @override = override
  end

  def approve!
    raise ArgumentError, "not_pending" unless @approval.status == "pending"
    raise ArgumentError, "not_approver" unless @override || @approval.approver_user_id == @actor_id

    ActiveRecord::Base.transaction do
      @approval.update!(
        status: "approved",
        approved_by_user_id: @actor_id,
        approved_at: Time.current,
        is_override: @override
      )
      maybe_advance!
      @approval
    end
  end

  def request_changes!(reason:)
    raise ArgumentError, "not_pending" unless @approval.status == "pending"

    offer = Offer.find(@approval.entity_id)
    version = OfferVersion.find(@approval.entity_version_id)
    ActiveRecord::Base.transaction do
      @approval.update!(
        status: "changes_requested",
        approved_by_user_id: @actor_id,
        approved_at: Time.current,
        reason: reason
      )
      Approval.where(entity_version_id: version.id, status: "pending").update_all(status: "cancelled")
      version.update!(approval_state: "changes_requested")
      offer.update!(status: "changes_requested")
      @approval
    end
  end

  private

  def maybe_advance!
    step = @approval.approval_policy_step
    policy = @approval.approval_policy
    version = OfferVersion.find(@approval.entity_version_id)
    offer = Offer.find(@approval.entity_id)

    step_approvals = Approval.where(entity_version_id: version.id, approval_policy_step_id: step.id)
    pending = step_approvals.where(status: "pending")
    approved = step_approvals.where(status: "approved")

    complete =
      case step.require_mode
      when "any" then approved.exists?
      when "all" then pending.none?
      else
        approved.count >= step.require_mode.to_i
      end
    return unless complete

    pending.update_all(status: "cancelled") if step.require_mode == "any"

    next_step = policy.steps.where("position > ?", step.position).order(:position).first
    if next_step
      OfferSubmitter.new(offer: offer, actor_id: @actor_id).send(
        :open_step!, offer, version, policy,
        OfferContext.new(offer: offer, fields: version.fields),
        position: next_step.position
      )
    else
      version.update!(approval_state: "approved")
      offer.update!(status: "approved")
      ChangeWriter.call(
        record: offer,
        action: "offer.approved",
        event_type: "offer.approved",
        payload: { "version_id" => version.id },
        changes: { "status" => %w[pending_approval approved] }
      )
    end
  end
end
