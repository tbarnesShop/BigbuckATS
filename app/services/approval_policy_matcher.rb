# frozen_string_literal: true

# First matching policy by priority wins; catch-all is the fallback.
class ApprovalPolicyMatcher
  def self.call(applies_to:, context:)
    new(applies_to: applies_to, context: context).call
  end

  def initialize(applies_to:, context:)
    @applies_to = applies_to
    @context = context.deep_stringify_keys
  end

  def call
    policies = ApprovalPolicy.where(applies_to: @applies_to).order(priority: :desc, created_at: :asc)
    matched = policies.reject(&:is_catch_all).find { |p| matches?(p) }
    return matched if matched

    catch_all = policies.find(&:is_catch_all)
    raise ArgumentError, "approval_gap: no catch-all for #{@applies_to}" unless catch_all

    catch_all
  end

  private

  def matches?(policy)
    conditions = policy.conditions
    return true if conditions.blank?

    RuleEngine.evaluate!(conditions, @context)
  rescue RuleEngine::Error => e
    # A broken condition must not read as "no match": that would let a strict
    # policy silently fall through to the catch-all.
    raise ArgumentError, "approval_gap: condition_error in policy #{policy.key} (#{e.message})"
  end
end
