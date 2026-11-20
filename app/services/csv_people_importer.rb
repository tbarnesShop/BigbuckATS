# frozen_string_literal: true

require "csv"

# Imports people from a typical ATS CSV with field mapping and provenance.
#
# Rows are staged first (bulk insert into import_rows), then processed in
# chunks of CHUNK rows, each in its own short transaction, so a 50,000-row
# import never holds one giant transaction. Large imports (or async: true) are
# processed by ProcessImportJob; the run reports progress as chunks finish.
#
# Cleaning on the way in: emails and phones are normalized the same way as
# PersonContactPoint, and existing people are matched by source id, then by
# canonical email, before a new person is created.
class CsvPeopleImporter
  Result = Struct.new(:run, :people, keyword_init: true)

  CHUNK = 500
  STAGE_BATCH = 1_000
  ASYNC_THRESHOLD = 500

  DEFAULT_MAPPING = {
    "email" => "primary_email",
    "name" => "display_name",
    "phone" => "primary_phone",
    "id" => "source_id"
  }.freeze

  def self.call(csv_string:, field_mapping: DEFAULT_MAPPING, source_system: "csv", dry_run: false,
                actor_id: Current.actor_id, async: nil)
    new(
      csv_string: csv_string, field_mapping: field_mapping,
      source_system: source_system, dry_run: dry_run, actor_id: actor_id, async: async
    ).call
  end

  def initialize(csv_string:, field_mapping:, source_system:, dry_run:, actor_id:, async:)
    @csv_string = csv_string
    @field_mapping = field_mapping.stringify_keys
    @source_system = source_system
    @dry_run = dry_run
    @actor_id = actor_id
    @async = async
  end

  def call
    rows = CSV.parse(@csv_string, headers: true)
    async = @async.nil? ? rows.size > ASYNC_THRESHOLD : @async
    run = ImportRun.create!(
      source: "csv",
      entity: "people",
      status: @dry_run ? "dry_run" : (async ? "queued" : "processing"),
      field_mapping: @field_mapping.merge("_source_system" => @source_system),
      row_count: rows.size,
      actor_id: @actor_id
    )
    stage!(run, rows)

    if @dry_run
      run.import_rows.where(status: "pending").update_all(status: "skipped", updated_at: Time.current)
      run.update!(processed_count: rows.size, finished_at: Time.current)
      return Result.new(run: run.reload, people: [])
    end

    if async
      ProcessImportJob.perform_later(run.id)
      return Result.new(run: run.reload, people: [])
    end

    people = ImportProcessor.new(run).process!
    Result.new(run: run.reload, people: people)
  end

  private

  def stage!(run, rows)
    now = Time.current
    errors = 0
    rows.each_slice(STAGE_BATCH).with_index do |slice, slice_index|
      records = slice.each_with_index.map do |row, idx|
        mapped = map_row(row)
        missing = mapped["primary_email"].blank? || mapped["display_name"].blank?
        errors += 1 if missing
        {
          id: Id.generate, organization_id: run.organization_id, import_run_id: run.id,
          row_number: (slice_index * STAGE_BATCH) + idx + 1, source_id: mapped["source_id"],
          raw: row.to_h, mapped: mapped, status: missing ? "error" : "pending",
          error_message: (missing ? "missing_required" : nil), created_at: now, updated_at: now
        }
      end
      ImportRow.insert_all(records) if records.any?
    end
    run.update_columns(error_count: errors, processed_count: errors, updated_at: now) if errors.positive?
  end

  def map_row(row)
    out = {}
    @field_mapping.each do |csv_col, attr|
      out[attr] = row[csv_col]&.to_s&.strip
    end
    out["primary_email"] = PersonContactPoint.normalize_email(out["primary_email"]).presence if out.key?("primary_email")
    out["primary_phone"] = PersonContactPoint.normalize_phone(out["primary_phone"]).presence if out.key?("primary_phone")
    out
  end
end
