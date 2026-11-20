# frozen_string_literal: true

# Dry-run for enrolling many people: says who would be enrolled and, for everyone else, the one
# reason they would be skipped. Nothing is written. Committing re-plans, so a stale review can
# never enroll someone who became ineligible in the meantime.
class EnrollmentPlanner
  MAX_PEOPLE = 500
  REASONS = %w[no_email do_not_contact opted_out active_enrollment company_dnc cooldown consent_blocked].freeze

  Plan = Struct.new(:eligible, :skipped, keyword_init: true) do
    def counts
      { "total" => eligible.size + skipped.size, "will_enroll" => eligible.size,
        "skipped" => skipped.group_by { |s| s[:reason] }.transform_values(&:size) }
    end
  end

  def self.plan(people:, exclude_person_ids: [])
    excluded = Set.new(Array(exclude_person_ids))
    eligible = []
    skipped = []
    people.first(MAX_PEOPLE).each do |person|
      if excluded.include?(person.id)
        skipped << { person: person, reason: "excluded" }
      elsif (reason = skip_reason(person))
        skipped << { person: person, reason: reason }
      else
        eligible << person
      end
    end
    Plan.new(eligible: eligible, skipped: skipped)
  end

  def self.skip_reason(person)
    return "no_email" if person.primary_email.blank?

    OutreachPolicy.check!(person: person)
    ConsentGate.check!(person: person, action: "sequence.enroll")
    nil
  rescue OutreachPolicy::Blocked => e
    e.code
  rescue ConsentGate::Blocked
    "consent_blocked"
  end
end
