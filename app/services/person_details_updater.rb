# frozen_string_literal: true

require "uri/mailto"

# Edit the visible record without silently attaching it to a different person.
class PersonDetailsUpdater
  def self.call(person:, attributes:)
    person.with_lock do
      attrs = attributes.to_h.stringify_keys
      %w[email phone].each do |kind|
        next unless attrs.key?(kind)
        raw = attrs.delete(kind).to_s.strip
        normalized = PersonContactPoint.normalize_for(kind, raw)
        if raw.present?
          raise ArgumentError, "Enter a valid email address" if kind == "email" && !URI::MailTo::EMAIL_REGEXP.match?(normalized)
          raise ArgumentError, "Enter a valid phone number" if kind == "phone" && normalized.blank?
          conflict = PersonContactPoint.where(kind: kind, canonical_key: normalized).where.not(person_id: person.id).exists?
          raise ArgumentError, "This contact cannot be assigned. Check for a duplicate record." if conflict
        end
        person.contact_points.where(kind: kind, primary: true).each { |point| point.update!(primary: false) }
        if raw.present?
          point = person.contact_points.find_or_initialize_by(kind: kind, normalized_value: normalized)
          point.assign_attributes(value: raw, primary: true)
          point.save!
        end
        person.public_send("primary_#{kind}=", normalized.presence)
      end
      if (company = attrs.delete("affiliation"))
        company = company.to_h.stringify_keys
        row = company["id"].present? ? person.affiliations.find(company["id"]) : person.affiliations.build(current: true)
        row.company = Company.find(company.fetch("company_id"))
        row.title = company["title"].to_s.strip.presence
        row.save!
      end
      person.assign_attributes(attrs)
      ChangeWriter.call(record: person, action: "person.updated", event_type: "person.updated")
      person
    end
  end
end
