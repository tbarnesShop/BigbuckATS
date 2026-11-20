# frozen_string_literal: true

# Creates or advances an offer into pending_approval and opens the first step's requests.
class OfferSubmitter
  def self.create_draft!(application:, fields:, actor_id: Current.actor_id)
    new(application: application, fields: fields, actor_id: actor_id).create_draft!
  end

  def self.submit!(offer:, actor_id: Current.actor_id)
    new(offer: offer, actor_id: actor_id).submit!
  end

  def initialize(application: nil, offer: nil, fields: nil, actor_id: nil)
    @application = application
    @offer = offer
    @fields = fields
    @actor_id = actor_id
  end

  def create_draft!
    ActiveRecord::Base.transaction do
      offer = Offer.create!(application: @application, status: "draft", live_key: @application.id)
      version = OfferVersion.create!(
        offer: offer,
        version_number: 1,
        fields: @fields || {},
        approval_state: "not_required",
        created_by_type: "User",
        created_by_id: @actor_id
      )
      offer.update!(current_version: version)
      ChangeWriter.call(
        record: offer,
        action: "offer.created",
        event_type: "offer.created",
        payload: { "application_id" => @application.id },
        changes: { "status" => [ nil, "draft" ] }
      )
      offer
    end
  end

  def submit!
    offer = @offer
    raise ArgumentError, "not_draft" unless offer.status == "draft"

    version = offer.current_version
    context_builder = OfferContext.new(offer: offer, fields: version.fields)
    context = context_builder.build
    policy = ApprovalPolicyMatcher.call(applies_to: "offer", context: context)

    ActiveRecord::Base.transaction do
      version.update!(approval_policy: policy, approval_state: "pending")
      offer.update!(status: "pending_approval", version: offer.version + 1)
      open_step!(offer, version, policy, context_builder)
      ChangeWriter.call(
        record: offer,
        action: "offer.submitted",
        event_type: "offer.submitted",
        payload: { "approval_policy_id" => policy.id, "approval_policy_key" => policy.key },
        changes: { "status" => %w[draft pending_approval] }
      )
      offer
    end
  end

  private

  def open_step!(offer, version, policy, context_builder, position: nil)
    steps = policy.steps.order(:position)
    step = if position
             steps.find { |s| s.position == position }
    else
             steps.first
    end
    return mark_approved!(offer, version) unless step

    if step.step_when.present? && !step_when_met?(step, context_builder)
      skip_and_advance!(offer, version, policy, step, context_builder, reason: "step_when_false")
      return
    end

    resolved = ApproverResolver.call(
      specs: step.approvers,
      offer: offer,
      context_builder: context_builder,
      submitter_id: @actor_id || version.created_by_id,
      allow_self_approval: step.allow_self_approval
    )

    if resolved.empty?
      case step.if_no_approver
      when "skip"
        skip_and_advance!(offer, version, policy, step, context_builder, reason: "no_approver")
        return
      when "fallback"
        resolved = ApproverResolver.call(
          specs: [ step.fallback_approver ].compact,
          offer: offer,
          context_builder: context_builder,
          submitter_id: nil,
          allow_self_approval: true
        )
        # An empty fallback must not open a step with no approvals: the offer would wait forever.
        raise ArgumentError, "no_approver_block" if resolved.empty?
      else
        # "block", and any value we do not recognise, fail closed rather than skip an approval.
        raise ArgumentError, "no_approver_block"
      end
    end

    resolved.each do |r|
      Approval.create!(
        entity_type: "Offer",
        entity_id: offer.id,
        entity_version_id: version.id,
        approval_policy: policy,
        approval_policy_step: step,
        step_key: step.name.parameterize,
        step_position: step.position,
        approver_user_id: r.user_id,
        resolved_from: r.from,
        requested_by_user_id: @actor_id || version.created_by_id,
        requested_at: Time.current,
        status: "pending"
      )
    end
  end

  # A broken step_when must not silently skip an approval step.
  def step_when_met?(step, context_builder)
    RuleEngine.evaluate!(step.step_when, context_builder.build)
  rescue RuleEngine::Error => e
    raise ArgumentError, "approval_gap: step_when_error in step #{step.name} (#{e.message})"
  end

  def skip_and_advance!(offer, version, policy, step, context_builder, reason:)
    Approval.create!(
      entity_type: "Offer",
      entity_id: offer.id,
      entity_version_id: version.id,
      approval_policy: policy,
      approval_policy_step: step,
      step_key: step.name.parameterize,
      step_position: step.position,
      status: "skipped",
      reason: reason,
      requested_at: Time.current
    )
    next_pos = step.position + 1
    if policy.steps.exists?(position: next_pos)
      open_step!(offer, version, policy, context_builder, position: next_pos)
    else
      mark_approved!(offer, version)
    end
  end

  def mark_approved!(offer, version)
    version.update!(approval_state: "approved")
    offer.update!(status: "approved")
  end
end
