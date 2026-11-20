# frozen_string_literal: true

# Applies the highest-priority matching policy's retention rule.
class RetentionRunner
  def self.call(person:, as_of: Time.current, actor_id: Current.actor_id)
    new(person: person, as_of: as_of, actor_id: actor_id).call
  end

  def initialize(person:, as_of:, actor_id:)
    @person = person
    @as_of = as_of
    @actor_id = actor_id
  end

  def call
    if LegalHoldService.person_held?(@person.id)
      RetentionAction.create!(
        person: @person, action: "held", actor_id: @actor_id,
        details: { "reason" => "legal_hold" }, created_at: Time.current
      )
      return { action: "held" }
    end

    return { action: "skipped", reason: "open_application" } if Application.where(person_id: @person.id, status: "active").exists?
    return { action: "skipped", reason: "employee" } if @person.lifecycle_stage == "employee"
    return { action: "skipped", reason: "merged" } if @person.merged_into_id.present?

    policy = CompliancePolicyMatcher.call(person: @person).max_by(&:priority)
    return { action: "skipped", reason: "no_policy" } unless policy

    retention = (policy.requirements || {})["retention"] || {}
    months = parse_months(retention["afterLastActivity"])
    return { action: "skipped", reason: "no_retention" } unless months

    last_activity = [ @person.updated_at, Application.where(person_id: @person.id).maximum(:updated_at) ].compact.max
    return { action: "skipped", reason: "still_active" } if last_activity && last_activity > @as_of - months.months

    case retention["action"].to_s
    when "anonymize"
      PersonEraser.call(person: @person, mode: "anonymize", actor_id: @actor_id)
      { action: "anonymized", policy: policy.key }
    when "delete"
      PersonEraser.call(person: @person, mode: "delete", actor_id: @actor_id)
      { action: "deleted", policy: policy.key }
    when "review"
      RetentionAction.create!(
        person: @person, action: "review_queued", compliance_policy_id: policy.id,
        actor_id: @actor_id, details: { "policy" => policy.key }, created_at: Time.current
      )
      { action: "review_queued", policy: policy.key }
    else
      { action: "skipped", reason: "unknown_action" }
    end
  end

  private

  def parse_months(value)
    return nil if value.blank?
    return value if value.is_a?(Integer)

    m = value.to_s.match(/\A(\d+)\s*mo\z/i)
    m ? m[1].to_i : nil
  end
end
