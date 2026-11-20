# frozen_string_literal: true

require_relative "recovery"

module LocalSecurity
  class Drill
    def initialize(database)
      @database = database
    end

    def run!
      raise Error, "Run this drill offline (LOCAL_SECURITY_OFFLINE=1)" unless ENV["LOCAL_SECURITY_OFFLINE"] == "1"
      original_environment = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "test"
      @database.provision!
      @database.verify!
      canary = SecureRandom.uuid
      @database.run!("runtime", "bin/rails", "runner", <<~RUBY, extra: { "LOCAL_CANARY" => canary })
        org = Organization.create!(name: "Recovery drill", slug: "drill-" + ENV.fetch("LOCAL_CANARY"))
        Current.set(organization_id: org.id) do
          person = Person.create!(id: ENV.fetch("LOCAL_CANARY"), display_name: "Recovery canary", primary_email: "synthetic@example.invalid")
          DocumentUploader.call(person: person, filename: "resume.pdf", content_type: "application/pdf", io: StringIO.new("%PDF-1.4 synthetic recovery canary"))
        end
      RUBY
      recovery = Recovery.new(@database)
      snapshot = recovery.backup!
      @database.run!("runtime", "bin/rails", "runner", <<~RUBY, extra: { "LOCAL_CANARY" => canary })
        person = Person.unscoped.find(ENV.fetch("LOCAL_CANARY"))
        Current.set(organization_id: person.organization_id) { PersonEraser.call(person: person) }
        RetentionAction.unscoped.where(person_id: person.id).each { |action| ErasedDocumentCleanupJob.perform_now(action.id) }
      RUBY
      ledger = recovery.export_erasures!
      # Prove stale, mismatched and corrupted metadata cannot start a restore.
      original = Database.read_signed(ledger)
      [ original.merge("exported_at" => (Time.now.utc - 600).iso8601), original.merge("database" => "wrong") ].each do |invalid|
        Database.write_signed(ledger, invalid)
        begin
          recovery.validate!(snapshot, ledger)
          raise "Invalid ledger was accepted"
        rescue Error
          # Expected fail-closed result.
        end
      end
      File.write(ledger, '{"data":"tampered","hmac":"invalid"}')
      begin
        recovery.validate!(snapshot, ledger)
        raise "Corrupt ledger was accepted"
      rescue Error
        # Expected fail-closed result.
      end
      Database.write_signed(ledger, original)
      # SQL and file integrity are independently enforced.
      sql_path = File.join(snapshot, "database.sql")
      File.open(sql_path, "a") { |file| file.write("\n-- tampered\n") }
      begin
        recovery.validate!(snapshot, ledger)
        raise "Corrupt SQL was accepted"
      rescue Error
        # Expected fail-closed result.
      ensure
        File.truncate(sql_path, File.size(sql_path) - "\n-- tampered\n".bytesize)
      end
      storage_canary = File.join(snapshot, "storage", "unlisted")
      File.write(storage_canary, "tampered")
      begin
        recovery.validate!(snapshot, ledger)
        raise "Corrupt storage was accepted"
      rescue Error
        # Expected fail-closed result.
      ensure
        File.delete(storage_canary)
      end
      held = Database.new("bigbuck_recovery_#{SecureRandom.hex(6)}")
      held.provision!(schema: sql_path)
      FileUtils.cp_r(File.join(snapshot, "storage"), File.join(held.directory, "storage"))
      FileUtils.cp(File.join(snapshot, "manifest.json"), File.join(held.directory, "SOURCE.json"))
      held.run!("maintenance", "bin/rails", "runner", <<~RUBY, extra: { "LOCAL_CANARY" => canary, "LOCAL_ERASURE_LEDGER" => ledger })
        blob = ActiveStorage::Blob.first!
        original_service = blob.service_name
        blob.update_columns(service_name: "private_documents")
        begin
          ErasureRecovery.validate_storage!
          raise "External storage was accepted"
        rescue LocalSecurity::Error
          puts "External storage was rejected before constructing a cloud client."
        ensure
          blob.update_columns(service_name: original_service)
        end
        original_key = blob.key
        blob.update_columns(key: "../../outside")
        begin
          ErasureRecovery.validate_storage!
          raise "Traversal storage key was accepted"
        rescue LocalSecurity::Error
          puts "Traversal storage key was rejected before cleanup."
        ensure
          blob.update_columns(key: original_key)
        end
        person = Person.unscoped.find(ENV.fetch("LOCAL_CANARY"))
        Current.set(organization_id: person.organization_id) do
          user = User.create!(name: "Drill operator", email: "drill-#{SecureRandom.hex(8)}@example.invalid")
          LegalHoldService.place!(subject: person, reason: "Synthetic drill hold", actor_id: user.id)
        end
        begin
          ErasureRecovery.replay!(ENV.fetch("LOCAL_ERASURE_LEDGER"))
          raise "Held recovery was accepted"
        rescue PersonEraser::Held
          raise "Held person was modified" if person.reload.erased?
          puts "Legal hold blocked recovery; database remains quarantined."
        end
      RUBY
      begin
        held.require_ready!
        raise "Held database readiness gate failed"
      rescue Error
        # Expected absence of READY marker.
      end
      target = recovery.recover!(snapshot, ledger)
      target.run!("runtime", "bin/rails", "runner", <<~RUBY, extra: { "LOCAL_CANARY" => canary })
        person = Person.unscoped.find(ENV.fetch("LOCAL_CANARY"))
        raise "Erasure replay failed" unless person.erased? && PersonEraser.verify(person).empty?
        raise "File cleanup failed" if ActiveStorage::Blob.exists?
        puts "Recovery canary is erased and its uploaded file is gone."
      RUBY
      puts "Offline recovery drill passed. Source and recovered databases remain available for inspection."
    ensure
      ENV["RAILS_ENV"] = original_environment if defined?(original_environment)
    end
  end
end
