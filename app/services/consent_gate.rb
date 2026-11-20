# frozen_string_literal: true

# Blocks configured actions unless the named consent is currently granted.
class ConsentGate
  Error = Class.new(StandardError)
  Blocked = Class.new(Error)

  def self.check!(person:, action:)
    new(person: person, action: action).check!
  end

  def initialize(person:, action:)
    @person = person
    @action = action.to_s
  end

  def check!
    policies = CompliancePolicyMatcher.call(person: @person)
    policies.each do |policy|
      policy.blocks_req.each do |block|
        next unless (block["action"] || block[:action]).to_s == @action

        unless_cfg = block["unless"] || block[:unless] || {}
        purpose_key = unless_cfg["consent"] || unless_cfg[:consent]
        next if purpose_key.blank?

        purpose = ConsentPurpose.find_by(key: purpose_key)
        raise Blocked, "blocked_by_policy:#{policy.key}:missing_purpose:#{purpose_key}" unless purpose

        current = Consent.current_for(person_id: @person.id, purpose_id: purpose.id)
        next if current&.granted?

        raise Blocked, "blocked_by_policy:#{policy.key}:consent:#{purpose_key}"
      end
    end
    true
  end
end
