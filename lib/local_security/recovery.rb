# frozen_string_literal: true

require_relative "database"

module LocalSecurity
  # A local offline rehearsal, not a production backup service.
  class Recovery
    attr_reader :database

    def initialize(database)
      @database = database
    end

    def backup!
      offline!
      path = File.join(database.directory, "snapshots", SecureRandom.hex(12))
      FileUtils.mkdir_p(path, mode: 0700)
      database.run!("maintenance", "bin/rails", "runner", "ErasureRecovery.validate_storage!")
      database.mysql_command("mysqldump", "migrator", output: File.join(path, "database.sql"),
        arguments: %w[--single-transaction --routines --triggers --no-tablespaces --set-gtid-purged=OFF --skip-add-locks])
      # Bind restored triggers to the target migrator, without global SET_USER_ID.
      sql_path = File.join(path, "database.sql")
      sql = File.read(sql_path).gsub(%r{/\*!50017 DEFINER=`[^`]+`@`[^`]+`\*/}, "/*!50017*/")
      File.write(sql_path, sql)
      source = File.join(database.directory, "storage")
      files(source)
      FileUtils.mkdir_p(File.join(path, "storage"), mode: 0700)
      FileUtils.cp_r("#{source}/.", File.join(path, "storage")) if File.directory?(source)
      Database.write_signed(File.join(path, "manifest.json"), {
        "database" => database.name, "captured_at" => Time.now.utc.iso8601,
        "sql_sha256" => Digest::SHA256.file(File.join(path, "database.sql")).hexdigest,
        "storage" => hashes(File.join(path, "storage"))
      })
      puts "Created private snapshot: #{path}"
      path
    end

    def export_erasures!
      path = File.join(database.directory, "erasures-#{SecureRandom.hex(12)}.json")
      database.run!("maintenance", "bin/rails", "runner", "ErasureRecovery.export!(ENV.fetch('LOCAL_ERASURE_LEDGER'))",
        extra: { "LOCAL_ERASURE_LEDGER" => path })
      puts "Exported signed erasure ledger: #{path}"
      path
    end

    def validate!(snapshot, ledger_path)
      manifest = Database.read_signed(File.join(snapshot, "manifest.json"))
      ledger = Database.read_signed(ledger_path)
      raise Error, "Snapshot/ledger source mismatch" unless manifest.fetch("database") == database.name && ledger.fetch("database") == database.name
      captured = Time.iso8601(manifest.fetch("captured_at"))
      exported = Time.iso8601(ledger.fetch("exported_at"))
      raise Error, "Export a fresh ledger after the snapshot with writers stopped" unless exported >= captured && exported <= Time.now.utc && exported >= Time.now.utc - 300
      raise Error, "Snapshot SQL integrity failed" unless Digest::SHA256.file(File.join(snapshot, "database.sql")).hexdigest == manifest.fetch("sql_sha256")
      raise Error, "Snapshot storage integrity failed" unless hashes(File.join(snapshot, "storage")) == manifest.fetch("storage")
      ledger
    rescue KeyError, ArgumentError => error
      raise Error, "Invalid recovery inputs: #{error.class}"
    end

    def recover!(snapshot, ledger_path)
      offline!
      validate!(snapshot, ledger_path)
      target = Database.new("bigbuck_recovery_#{SecureRandom.hex(6)}")
      target.provision!(schema: File.join(snapshot, "database.sql"))
      FileUtils.cp_r(File.join(snapshot, "storage"), File.join(target.directory, "storage"))
      FileUtils.cp(File.join(snapshot, "manifest.json"), File.join(target.directory, "SOURCE.json"))
      begin
        target.require_ready!
        raise Error, "Recovery readiness gate failed"
      rescue Error => error
        raise unless error.message.include?("quarantined")
      end
      target.run!("maintenance", "bin/rails", "runner", "ErasureRecovery.replay!(ENV.fetch('LOCAL_ERASURE_LEDGER'))",
        extra: { "LOCAL_ERASURE_LEDGER" => File.expand_path(ledger_path) })
      Database.write_signed(File.join(target.directory, "READY.json"), {
        "database" => target.name, "verified" => true, "verified_at" => Time.now.utc.iso8601,
        "ledger_sha256" => Digest::SHA256.file(ledger_path).hexdigest
      })
      begin
        target.run!("runtime", "bin/rails", "runner", "puts 'Recovered runtime passed identity, permission and readiness checks.'")
      rescue StandardError
        File.delete(File.join(target.directory, "READY.json"))
        raise
      end
      puts "Recovered and verified isolated database: #{target.name}"
      target
    end

    private

    def offline!
      raise Error, "Stop app writers and workers and set LOCAL_SECURITY_OFFLINE=1" unless ENV["LOCAL_SECURITY_OFFLINE"] == "1"
    end

    def files(root)
      return [] unless File.exist?(root)
      raise Error, "Storage symlinks are forbidden" if File.symlink?(root)
      Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).reject { |path| %w[. ..].include?(File.basename(path)) }.each do |path|
        raise Error, "Storage contains unsafe filesystem entries" if File.symlink?(path) || (!File.file?(path) && !File.directory?(path))
      end.select { |path| File.file?(path) }.sort
    end

    def hashes(root)
      files(root).to_h { |path| [ path.delete_prefix("#{root}/"), Digest::SHA256.file(path).hexdigest ] }
    end
  end
end
