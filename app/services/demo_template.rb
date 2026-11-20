# frozen_string_literal: true

# Seed the lab dataset once, keep it as a snapshot, and copy the snapshot into each sandbox.
#
# Running the seeder costs tens of thousands of single-row statements, real service calls and PDF
# uploads, so on a networked database a sandbox took minutes. A copy is one read of the snapshot and
# a few batched INSERTs per table: every id is replaced with a fresh one (references, polymorphic ids
# and ids inside JSON follow), datetimes move forward by the snapshot's age so "3 days ago" stays
# 3 days ago, and résumé files are shared rather than uploaded again.
#
# The seeder runs inside a transaction that is rolled back once its rows are captured, so the
# template never exists as a live tenant: workers, sign-in and the careers site cannot touch it.
# Only the files (already in storage) and their blob rows, plus any staff users it created, are kept.
#
# The snapshot is rebuilt when the code or schema that produces it changes (see .fingerprint), when it
# is older than MAX_AGE (so every nightly refresh), or on demand (FORCE_TEMPLATE=1 for demo:prepare).
class DemoTemplate
  KEY = "lab"
  FORMAT = 1
  # The nightly 03:00 refresh rebuilds it, so copies made right after start from a "now" of a few
  # minutes ago and interview times keep the seeded working hours. A week-old snapshot moved every
  # time by its exact age, which put 2pm interviews at 7:50pm.
  MAX_AGE = 20.hours
  # Copy shifts round to this, so seeded :00/:30 times stay on the half hour. The seeder keeps at
  # least two hours between "now" and anything it places before or after it, so 15 minutes is safe.
  SHIFT_STEP = 30.minutes
  LOCK_WAIT = 900 # seconds; a build takes a few minutes on a networked database
  BATCH_BYTES = 1_000_000
  UUID = /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/
  SKIP_TABLES = %w[demo_sandboxes].freeze
  # Bearer secrets are minted per sign-in and must never be shared between tenants.
  SECRET_TABLES = %w[api_credentials oauth_identities].freeze
  # Rows outside any tenant that the seeder may create and the copies point at.
  GLOBAL_TABLES = %w[users active_storage_blobs].freeze
  FINGERPRINT_GLOBS = %w[
    lib/big_buck_dataset.rb lib/big_buck_demo_seed.rb lib/big_buck_demo/**/*.rb
    app/models/**/*.rb app/services/**/*.rb config/data_classes.yml db/structure.sql
  ].freeze

  Stats = Struct.new(:tables, :rows, :attachments, :seconds, keyword_init: true)

  def self.enabled?
    ENV.fetch("BIGBUCK_DEMO_TEMPLATE", "1") == "1"
  end

  def self.fingerprint
    @fingerprint ||= begin
      digest = Digest::SHA256.new
      digest << DemoWorkspaces.seeder.name << FORMAT.to_s
      FINGERPRINT_GLOBS.flat_map { |glob| Dir[Rails.root.join(glob)] }.sort.each do |path|
        digest << path.delete_prefix(Rails.root.to_s) << File.read(path)
      end
      digest.hexdigest
    end
  end

  def self.current
    DemoTemplateSnapshot.select(:key, :fingerprint, :seeded_at, :blob_ids, :row_count, :byte_size).find_by(key: KEY)
  end

  def self.fresh?(meta)
    meta.present? && meta.fingerprint == fingerprint && meta.seeded_at > MAX_AGE.ago
  end

  # Returns fresh snapshot metadata, building the snapshot first when needed. Safe across workers.
  def self.ensure!(force: false)
    meta = current
    return meta if !force && fresh?(meta)

    with_lock do
      meta = current
      next meta if !force && fresh?(meta)

      build!
      current
    end
  end

  # Seeds a throwaway tenant, captures it, rolls it back, then stores the capture.
  def self.build!
    started = Time.current
    conn = ActiveRecord::Base.connection
    captured = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      result = Current.set(organization_id: nil, principal: nil, actor_type: "system", source_surface: "system") do
        DemoWorkspaces.seeder.call(slug: "big-buck-lab-template-#{SecureRandom.hex(4)}")
      end
      captured = capture(conn, result.organization.reload)
      raise ActiveRecord::Rollback
    end
    raise "demo template capture failed" unless captured

    previous = current&.blob_ids.to_a
    bytes = Zlib::Deflate.deflate(JSON.generate(captured), Zlib::BEST_SPEED)
    blob_ids = captured["attachments"].map { |row| row[3].to_i }.uniq
    rows = captured["tables"].sum { |_, _, table_rows| table_rows.size }
    now = Time.current
    ActiveRecord::Base.transaction(requires_new: true) do
      # The rollback took the seeder's new users and blob rows with it; the copies point at them.
      captured["globals"].each { |table, (fields, table_rows)| Copier.new(conn, 0).insert!(table, fields, table_rows, verbatim: true) }
      DemoTemplateSnapshot.upsert({ key: KEY, fingerprint: fingerprint, seeded_at: started, payload: bytes, blob_ids: blob_ids,
                                    row_count: rows, byte_size: bytes.bytesize, created_at: now, updated_at: now })
    end
    release_blobs!(previous.map(&:to_i) - blob_ids)
    Rails.logger.info({ event: "demo.template_built", rows: rows, bytes: bytes.bytesize, files: blob_ids.size,
                        seconds: (Time.current - started).round(1) }.to_json)
  end

  def self.capture(conn, org)
    raw = conn.raw_connection
    tenant_ids = Set.new
    tables = tenant_tables(conn).filter_map do |table|
      next if SECRET_TABLES.include?(table)

      result = raw.query("SELECT * FROM #{conn.quote_table_name(table)} WHERE organization_id = #{conn.quote(org.id)}", cast: false, as: :array)
      rows = utf8(result.to_a)
      next if rows.empty?

      id_at = result.fields.index("id")
      rows.each { |row| tenant_ids << row[id_at].downcase }
      [ table, result.fields, rows ]
    end
    attachments = utf8(attachment_rows(conn, org.id).map { |row| row.drop(1) })
    referenced = Set.new
    tables.each { |_, _, rows| rows.each { |row| row.each { |v| v.scan(UUID) { |id| referenced << id.downcase } if v.is_a?(String) && v.length >= 36 } } }
    referenced -= tenant_ids
    referenced.delete(org.id.downcase)
    {
      "format" => FORMAT, "organization_id" => org.id,
      "organization" => { "name" => org.name, "settings" => org.settings.to_h, "repository_lock" => org.repository_lock },
      "tables" => tables, "attachments" => attachments,
      "globals" => {
        "users" => global_rows(conn, "users", "id", referenced.to_a),
        "active_storage_blobs" => global_rows(conn, "active_storage_blobs", "id", attachments.map { |row| row[3] }.uniq)
      }
    }
  end

  def self.global_rows(conn, table, key, ids)
    return [ [], [] ] if ids.empty?

    list = ids.map { |id| conn.quote(id) }.join(",")
    result = conn.raw_connection.query("SELECT * FROM #{conn.quote_table_name(table)} WHERE #{conn.quote_column_name(key)} IN (#{list})", cast: false, as: :array)
    [ result.fields, utf8(result.to_a) ]
  end

  # mysql2 hands JSON columns back as binary strings when casting is off; the snapshot is JSON text.
  def self.utf8(rows)
    rows.each do |row|
      row.map! do |value|
        next value unless value.is_a?(String) && value.encoding != Encoding::UTF_8

        text = value.dup.force_encoding(Encoding::UTF_8)
        raise ArgumentError, "demo template rows must be UTF-8 text" unless text.valid_encoding?

        text
      end
    end
  end

  # Files of an older snapshot that no tenant uses any more.
  def self.release_blobs!(ids)
    return if ids.empty?

    ActiveStorage::Blob.where(id: ids).where.not(id: ActiveStorage::Attachment.select(:blob_id)).find_each(&:purge)
  end

  def self.protected_blob_ids
    current&.blob_ids.to_a.map(&:to_i)
  end

  # The decoded snapshot. Not cached: it is ~45 MB of Ruby objects for the enriched dataset, read about
  # once an hour per sandbox, and decoding takes well under a second.
  def self.payload(_meta = nil)
    JSON.parse(Zlib::Inflate.inflate(DemoTemplateSnapshot.where(key: KEY).pick(:payload)))
  end

  def self.with_lock
    conn = ActiveRecord::Base.connection
    name = conn.quote("bigbuck-demo-#{ActiveRecord::Base.connection_db_config.database}-template")
    acquired = conn.uncached { conn.select_value("SELECT GET_LOCK(#{name}, #{LOCK_WAIT})") }.to_i == 1
    raise DemoWorkspaces::Error.new("sandbox_busy", "The lab template is being rebuilt. Try again shortly.") unless acquired
    begin
      yield
    ensure
      conn.uncached { conn.select_value("SELECT RELEASE_LOCK(#{name})") }
    end
  end

  # Tables holding tenant rows, in a stable order.
  def self.tenant_tables(conn = ActiveRecord::Base.connection)
    conn.tables.sort.select do |table|
      !SKIP_TABLES.include?(table) && conn.columns(table).any? { |column| column.name == "organization_id" }
    end
  end

  # Active Storage rows carry no organization_id; find a tenant's attachments through their records.
  # Returns [id, name, record_type, record_id, blob_id, created_at] rows.
  def self.attachment_rows(conn, org_id)
    types = conn.select_values("SELECT DISTINCT record_type FROM active_storage_attachments")
    types.flat_map do |type|
      table = type.safe_constantize.try(:table_name)
      next [] unless table && conn.columns(table).any? { |column| column.name == "organization_id" }

      conn.raw_connection.query(<<~SQL.squish, cast: false, as: :array).to_a
        SELECT a.id, a.name, a.record_type, a.record_id, a.blob_id, a.created_at
        FROM active_storage_attachments a JOIN #{conn.quote_table_name(table)} r ON r.id = a.record_id
        WHERE a.record_type = #{conn.quote(type)} AND r.organization_id = #{conn.quote(org_id)}
      SQL
    end
  end

  # Writes the snapshot into a new organization with the given slug. Runs inside the caller's
  # transaction (DemoWorkspaces.refresh!). Returns [organization, Stats].
  def self.copy_into(slug:, meta: current)
    clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    raise ArgumentError, "demo template missing" unless meta

    data = payload(meta)
    conn = ActiveRecord::Base.connection
    copier = Copier.new(conn, Time.current - meta.seeded_at)
    data["tables"].each do |_, fields, rows|
      id_at = fields.index("id")
      rows.each { |row| copier.map_id(row[id_at]) }
    end
    org_id = copier.map_id(data["organization_id"], fresh: true)

    conn.execute("SET FOREIGN_KEY_CHECKS=0")
    insert_organization!(copier, data["organization"], org_id, slug)
    data["tables"].each { |table, fields, rows| copier.insert!(table, fields, rows) }
    attachments = data["attachments"]
    copier.insert!("active_storage_attachments", %w[name record_type record_id blob_id created_at], attachments) if attachments.any?
    conn.execute("SET FOREIGN_KEY_CHECKS=1")

    stats = Stats.new(tables: data["tables"].size, rows: data["tables"].sum { |_, _, rows| rows.size },
                      attachments: attachments.size, seconds: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - clock).round(2))
    [ Organization.find(org_id), stats ]
  end

  def self.insert_organization!(copier, org, org_id, slug)
    settings = JSON.parse(copier.rewrite(org["settings"].to_json))
    now = Time.current
    Organization.insert!({ id: org_id, name: org["name"], slug: slug, settings: settings,
                           repository_lock: org["repository_lock"], created_at: now, updated_at: now })
  end

  # Rewrites snapshot rows for a new tenant and writes them in large batches.
  class Copier
    def initialize(conn, shift)
      @conn = conn
      @shift = (shift.to_f / SHIFT_STEP).round * SHIFT_STEP.to_f
      @shift_ms = (@shift * 1000).round
      @shift_days = (@shift / 1.day).round
      @ids = {}
    end

    # Ids keep their UUIDv7 time order, moved by the snapshot's age, with fresh random bits.
    def map_id(old, fresh: false)
      key = old.downcase
      @ids[key] ||= (fresh || key[14] != "7") ? Id.generate : shifted_id(key)
    end

    def rewrite(text)
      return text unless text.length >= 36 && text.include?("-")

      text.gsub(UUID) { |match| @ids.fetch(match.downcase, match) }
    end

    # verbatim: rows are written unchanged and existing keys are kept (INSERT IGNORE).
    def insert!(table, fields, rows, verbatim: false)
      return if rows.empty?

      columns = @conn.columns(table).index_by(&:name)
      kinds = fields.map { |field| verbatim ? :verbatim : kind(columns.fetch(field).sql_type) }
      verb = verbatim ? "INSERT IGNORE INTO" : "INSERT INTO"
      head = "#{verb} #{@conn.quote_table_name(table)} (#{fields.map { |f| @conn.quote_column_name(f) }.join(', ')}) VALUES "
      batch = []
      bytes = 0
      rows.each do |row|
        tuple = "(#{row.each_with_index.map { |value, i| literal(value, kinds[i]) }.join(',')})"
        if bytes + tuple.bytesize > BATCH_BYTES && batch.any?
          @conn.execute(head + batch.join(","))
          batch = []
          bytes = 0
        end
        batch << tuple
        bytes += tuple.bytesize + 1
      end
      @conn.execute(head + batch.join(",")) if batch.any?
    end

    private

    def kind(sql_type)
      type = sql_type.downcase
      return :datetime if type.start_with?("datetime", "timestamp")
      return :date if type == "date"

      :value
    end

    def literal(value, kind)
      return "NULL" if value.nil?

      case kind
      when :verbatim then @conn.quote(value)
      when :datetime then @conn.quote(shift_time(value))
      when :date then @conn.quote((Date.iso8601(value) + @shift_days).iso8601)
      else @conn.quote(rewrite(value))
      end
    end

    def shift_time(value)
      year, month, day, hour, min, sec, frac = value.match(/\A(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)(?:\.(\d+))?/).captures
      usec = (frac || "0").ljust(6, "0")[0, 6].to_i
      time = Time.utc(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, usec) + @shift
      time.strftime("%Y-%m-%d %H:%M:%S.%6N")
    end

    def shifted_id(old)
      hex = old.delete("-")
      millis = (hex[0, 12].to_i(16) + @shift_ms).clamp(0, (2**48) - 1)
      out = format("%012x", millis) + SecureRandom.hex(10)
      out[12] = "7"
      out[16] = "89ab"[out[16].to_i(16) & 3]
      "#{out[0, 8]}-#{out[8, 4]}-#{out[12, 4]}-#{out[16, 4]}-#{out[20, 12]}"
    end
  end
end
