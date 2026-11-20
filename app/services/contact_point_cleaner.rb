# frozen_string_literal: true

# Re-keys contact points with the current normalization rules, in batches.
# When a re-keyed value now belongs to another person, the point is kept as a
# held duplicate (canonical_key NULL, duplicate_of_person_id set) and a merge
# suggestion is opened, the same way PersonMatcher handles a collision. A point
# that duplicates one the same person already has is removed.
class ContactPointCleaner
  BATCH = 1_000

  def self.call(organization_ids: nil)
    totals = Hash.new(0)
    orgs = organization_ids ? Organization.where(id: organization_ids) : Organization.all
    orgs.find_each do |org|
      Current.set(organization_id: org.id, actor_type: "system", source_surface: "automation") do
        PersonContactPoint.find_each(batch_size: BATCH) { |point| totals[clean!(point)] += 1 }
        clean_people_columns!(totals)
      end
    end
    Rails.logger.info({ event: "contact_points.cleaned", totals: totals }.to_json)
    totals
  end

  def self.clean!(point)
    key = PersonContactPoint.normalize_for(point.kind, point.value)
    return :unchanged if key == point.normalized_value && (point.held_duplicate? || key == point.canonical_key)

    holder = PersonContactPoint.where(kind: point.kind, canonical_key: key).where.not(id: point.id).first
    if holder.nil?
      point.update!(normalized_value: key, canonical_key: point.held_duplicate? ? nil : key)
      :rekeyed
    elsif holder.person_id == point.person_id
      point.destroy!
      :removed_duplicate
    else
      point.update!(normalized_value: key, canonical_key: nil, duplicate_of_person_id: holder.person_id)
      a, b = [ point.person_id, holder.person_id ].minmax
      MergeSuggestion.find_or_create_by!(person_a_id: a, person_b_id: b) do |s|
        s.reason = "normalized_#{point.kind}"
        s.status = "open"
      end
      :held_for_merge
    end
  end

  def self.clean_people_columns!(totals)
    Person.where(erased_at: nil).where.not(primary_phone: [ nil, "" ]).find_each(batch_size: BATCH) do |person|
      phone = PersonContactPoint.normalize_phone(person.primary_phone)
      next if phone == person.primary_phone

      person.update!(primary_phone: phone)
      totals[:person_phone_rekeyed] += 1
    end
  end

  private_class_method :clean!, :clean_people_columns!
end
