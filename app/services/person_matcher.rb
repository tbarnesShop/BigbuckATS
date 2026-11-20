# frozen_string_literal: true

# Matching rules (architecture rule 2):
# - exact email attach (never overwrite fields)
# - phone/url/name -> merge suggestion only
# - employee/alumni only match verified email (or explicit user merge)
# - collisions with hidden people stay quiet
class PersonMatcher
  Result = Struct.new(:person, :attached, :suggestion, :held_duplicate, keyword_init: true)

  def self.find_or_create(display_name:, email: nil, phone: nil, url: nil, viewer: nil, source: nil, source_detail: nil)
    new(display_name: display_name, email: email, phone: phone, url: url, viewer: viewer,
      source: source, source_detail: source_detail).call
  end

  def initialize(display_name:, email: nil, phone: nil, url: nil, viewer: nil, source: nil, source_detail: nil)
    @source = source
    @source_detail = source_detail
    @display_name = display_name
    @email = email
    @phone = phone
    @url = url
    @viewer = viewer
  end

  def call
    raise Current::TenantRequired if Current.organization_id.blank?

    if @email.present?
      match = match_email(@email)
      return attach_to(match) if match
    end

    person = create_person_with_contacts
    suggest_non_email_matches(person)
    Result.new(person: person, attached: false, suggestion: nil, held_duplicate: false)
  end

  private

  def match_email(email)
    normalized = PersonContactPoint.normalize_email(email)
    point = PersonContactPoint.find_by(kind: "email", canonical_key: normalized)
    return nil unless point

    person = Person.find_by(id: point.person_id)
    return nil unless person
    return nil if person.merged_into_id.present? || person.erased_at.present?

    # Employees/alumni only auto-attach on a verified email.
    if person.employee_or_alumni? && !point.verified
      return :hidden
    end

    unless PersonVisibility.visible?(person, viewer: @viewer)
      # Quiet collision: create a new person with held duplicate.
      return :hidden
    end

    person
  end

  def attach_to(match)
    if match == :hidden
      person = create_person_with_contacts(hold_email_duplicate: true)
      return Result.new(person: person, attached: false, suggestion: nil, held_duplicate: true)
    end

    add_extra_contacts(match)
    Result.new(person: match, attached: true, suggestion: nil, held_duplicate: false)
  end

  def create_person_with_contacts(hold_email_duplicate: false)
    person = Person.create!(
      display_name: @display_name,
      primary_email: @email && PersonContactPoint.normalize_email(@email),
      primary_phone: @phone && PersonContactPoint.normalize_phone(@phone),
      lifecycle_stage: "prospect",
      visibility: "public",
      source: @source,
      source_detail: @source_detail,
      sourced_at: (@source ? Time.current : nil),
      sourced_by_user_id: (@source && Current.actor_id.presence)
    )

    if @email.present?
      existing = PersonContactPoint.find_by(kind: "email", canonical_key: PersonContactPoint.normalize_email(@email))
      PersonContactPoint.create!(
        person: person,
        kind: "email",
        value: @email,
        primary: true,
        duplicate_of_person_id: (hold_email_duplicate || existing) ? (existing&.person_id || existing_hidden_person_id) : nil
      )
    end

    add_contact!(person, "phone", @phone, primary: true) if @phone.present?
    add_contact!(person, "url", @url) if @url.present?

    person
  end

  def add_contact!(person, kind, value, primary: false)
    normalized = PersonContactPoint.normalize_for(kind, value)
    conflict = PersonContactPoint.find_by(kind: kind, canonical_key: normalized)
    PersonContactPoint.create!(
      person: person,
      kind: kind,
      value: value,
      primary: primary,
      duplicate_of_person_id: conflict&.person_id
    )
    maybe_suggest(person, conflict&.person_id, kind) if conflict
  end

  def existing_hidden_person_id
    normalized = PersonContactPoint.normalize_email(@email)
    PersonContactPoint.unscoped.where(
      organization_id: Current.organization_id,
      kind: "email",
      canonical_key: normalized
    ).pick(:person_id)
  end

  def add_extra_contacts(person)
    # Never overwrite fields; only add missing contact points.
    if @phone.present?
      normalized = PersonContactPoint.normalize_phone(@phone)
      unless person.contact_points.where(kind: "phone", normalized_value: normalized).exists?
        conflict = PersonContactPoint.find_by(kind: "phone", canonical_key: normalized)
        PersonContactPoint.create!(
          person: person,
          kind: "phone",
          value: @phone,
          duplicate_of_person_id: conflict&.person_id
        )
        maybe_suggest(person, conflict&.person_id, "phone")
      end
    end
  end

  def suggest_non_email_matches(person)
    if @phone.present?
      normalized = PersonContactPoint.normalize_phone(@phone)
      other = PersonContactPoint.where(kind: "phone", canonical_key: normalized).where.not(person_id: person.id).first
      maybe_suggest(person, other&.person_id, "phone") if other
    end

    if @url.present?
      normalized = PersonContactPoint.normalize_url(@url)
      other = PersonContactPoint.where(kind: "url", canonical_key: normalized).where.not(person_id: person.id).first
      maybe_suggest(person, other&.person_id, "url") if other
    end
  end

  def maybe_suggest(person_a, person_b_id, reason)
    return if person_b_id.blank?

    person_b = Person.find_by(id: person_b_id)
    return unless person_b
    return unless PersonVisibility.can_see_both?(person_a, person_b, viewer: @viewer)

    a, b = [ person_a.id, person_b.id ].minmax
    MergeSuggestion.find_or_create_by!(person_a_id: a, person_b_id: b) do |s|
      s.reason = reason
      s.status = "open"
    end
  end
end
