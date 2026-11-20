# frozen_string_literal: true

# Outreach hygiene: person DNC, company DNC lists, and org contact cooldown.
class OutreachPolicy
  DEFAULT_COOLDOWN_DAYS = 14

  class Blocked < StandardError
    attr_reader :code

    def initialize(code, message = code)
      @code = code
      super(message)
    end
  end

  def self.check!(person:)
    new(person: person).check!
  end

  def self.blocked?(person:)
    check!(person: person)
    false
  rescue Blocked
    true
  end

  def initialize(person:)
    @person = person
    @org = Organization.find(person.organization_id)
  end

  def check!
    raise Blocked.new("do_not_contact", "person is marked do not contact") if @person.do_not_contact
    raise Blocked.new("opted_out", "person opted out") if OptOut.blocked?(@person.primary_email)
    raise Blocked.new("active_enrollment", "person already has an active sequence") if active_enrollment?
    raise Blocked.new("company_dnc", "person works at a do-not-contact company") if company_dnc?
    raise Blocked.new("cooldown", "person contacted within cooldown window") if in_cooldown?
    true
  end

  def cooldown_days
    raw = @org.setting("contact_cooldown_days", DEFAULT_COOLDOWN_DAYS)
    [ [ raw.to_i, 0 ].max, 365 ].min
  end

  private

  def active_enrollment?
    SequenceEnrollment.where(person_id: @person.id, status: "active").exists?
  end

  def company_dnc?
    company_ids = PersonAffiliation.where(person_id: @person.id, current: true).pluck(:company_id)
    return true if company_ids.any? && DncCompany.where(company_id: company_ids).exists?

    domains = Company.where(id: company_ids).where.not(domain: nil).pluck(:domain).map { |d| d.to_s.downcase }
    email_domain = @person.primary_email.to_s.split("@").last&.downcase
    domains << email_domain if email_domain.present?
    domains.uniq!
    return false if domains.empty?

    DncCompany.where(domain: domains).exists?
  end

  def in_cooldown?
    days = cooldown_days
    return false if days.zero?

    since = days.days.ago
    Communication.where(person_id: @person.id, direction: "outbound")
                 .where("created_at >= ?", since).exists?
  end
end
