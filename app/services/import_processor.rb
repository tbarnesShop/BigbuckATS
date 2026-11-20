# frozen_string_literal: true

# Applies staged import rows in chunks, each in its own transaction. Safe to
# re-run: only pending rows are picked up, so a crashed job resumes where it
# stopped. Counters are updated once per chunk, not per row.
class ImportProcessor
  def initialize(run, chunk: CsvPeopleImporter::CHUNK)
    @run = run
    @chunk = chunk
    @source_system = run.field_mapping.to_h["_source_system"].presence || "csv"
  end

  def process!
    @run.update_columns(status: "processing", updated_at: Time.current) unless @run.status == "processing"
    people = []
    loop do
      rows = @run.import_rows.where(status: "pending").order(:row_number).limit(@chunk).to_a
      break if rows.empty?

      created = updated = failed = 0
      ImportRow.transaction do
        rows.each do |row|
          person, was_new = upsert_person!(row.mapped)
          people << person
          was_new ? created += 1 : updated += 1
          row.update_columns(status: was_new ? "created" : "updated", resource_type: "Person",
                             resource_id: person.id, updated_at: Time.current)
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
          failed += 1
          row.update_columns(status: "error", error_message: e.message.first(250), updated_at: Time.current)
        end
      end
      bump!(created: created, updated: updated, failed: failed, processed: rows.size)
    end
    @run.update_columns(status: "applied", finished_at: Time.current, updated_at: Time.current)
    people
  rescue StandardError
    @run.update_columns(status: "failed", updated_at: Time.current)
    raise
  end

  private

  def bump!(created:, updated:, failed:, processed:)
    ImportRun.where(id: @run.id).update_all([
      "created_count = created_count + ?, updated_count = updated_count + ?, error_count = error_count + ?, " \
      "processed_count = processed_count + ?, updated_at = ?",
      created, updated, failed, processed, Time.current
    ])
  end

  def upsert_person!(mapped)
    mapped = mapped.to_h
    email = mapped["primary_email"]
    person = find_existing(mapped["source_id"], email) || Person.new
    was_new = person.new_record?
    person.assign_attributes(
      display_name: mapped["display_name"],
      primary_email: email,
      primary_phone: mapped["primary_phone"].presence || person.primary_phone,
      source_system: person.source_system.presence || @source_system,
      source_id: person.source_id.presence || mapped["source_id"],
      lifecycle_stage: person.lifecycle_stage.presence || "candidate"
    )
    ChangeWriter.call(
      record: person,
      action: was_new ? "person.imported" : "person.import_updated",
      event_type: was_new ? "person.created" : "person.updated",
      payload: {
        "person_id" => person.id,
        "id" => person.id,
        "primary_email" => person.primary_email,
        "source_system" => @source_system,
        "source_id" => mapped["source_id"],
        "provenance" => "csv_import"
      },
      changes: { "primary_email" => [ nil, person.primary_email ] }
    )
    attach_contact!(person, "email", email)
    attach_contact!(person, "phone", mapped["primary_phone"])
    [ person, was_new ]
  end

  def find_existing(source_id, email)
    if source_id.present?
      found = Person.find_by(source_system: @source_system, source_id: source_id)
      return found if found
    end
    return nil if email.blank?

    point = PersonContactPoint.find_by(kind: "email", canonical_key: email)
    return Person.find_by(id: point.person_id, erased_at: nil, merged_into_id: nil) if point

    Person.find_by(primary_email: email, erased_at: nil, merged_into_id: nil)
  end

  # Adds the contact point unless the person already has it. If another person
  # holds the same canonical value, the point is kept as a held duplicate and a
  # merge suggestion is opened, as PersonMatcher does.
  def attach_contact!(person, kind, value)
    return if value.blank?

    key = PersonContactPoint.normalize_for(kind, value)
    return if person.contact_points.where(kind: kind, normalized_value: key).exists?

    holder = PersonContactPoint.find_by(kind: kind, canonical_key: key)
    if holder && holder.person_id != person.id
      PersonContactPoint.create!(person: person, kind: kind, value: value, duplicate_of_person_id: holder.person_id)
      a, b = [ person.id, holder.person_id ].minmax
      MergeSuggestion.find_or_create_by!(person_a_id: a, person_b_id: b) do |s|
        s.reason = "import_#{kind}"
        s.status = "open"
      end
    elsif holder.nil?
      PersonContactPoint.create!(person: person, kind: kind, value: value)
    end
  end
end
