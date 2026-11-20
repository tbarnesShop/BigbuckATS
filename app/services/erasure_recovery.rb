# frozen_string_literal: true

# Uses the existing erasure and cleanup services with isolated Disk storage.
class ErasureRecovery
  def self.validate_storage!
    database = LocalSecurity::Database.new
    raise LocalSecurity::Error, "Recovery database mismatch" unless ActiveRecord::Base.connection_db_config.database == database.name
    expected_root = File.join(database.directory, "storage")
    ActiveStorage::Blob.find_each { |blob| validate_key!(blob.key) }
    entries = RetentionAction.unscoped.flat_map { |action| Array(action.details["blobs"]) }
    entries.each { |entry| validate_key!(entry.fetch("key")) }
    services = ActiveStorage::Blob.distinct.pluck(:service_name)
    services << Rails.application.config.active_storage.service.to_s
    services += entries.map { |blob| blob.fetch("service_name") }
    services.uniq.each do |name|
      configuration = Rails.application.config.active_storage.service_configurations.fetch(name).deep_symbolize_keys
      unless configuration[:service] == "Disk" && File.expand_path(configuration.fetch(:root)) == expected_root
        raise LocalSecurity::Error, "Recovery requires isolated local Disk storage"
      end
      service = ActiveStorage::Blob.services.fetch(name)
      unless service.is_a?(ActiveStorage::Service::DiskService) && File.expand_path(service.root) == expected_root
        raise LocalSecurity::Error, "Recovery requires isolated local Disk storage"
      end
    end
    legacy = Document.unscoped.where.not(storage_key: nil).where.not("storage_key LIKE 'erased/%'").any? { |doc| !doc.file.attached? }
    if legacy || RetentionAction.unscoped.any? { |action| Array(action.details["legacy_keys"]).any? }
      raise LocalSecurity::Error, "Migrate legacy documents to Active Storage before recovery"
    end
  end

  def self.validate_key!(key)
    unless key.is_a?(String) && key.match?(/\A[a-zA-Z0-9_-]{1,255}\z/)
      raise LocalSecurity::Error, "Recovery requires opaque storage keys without path components"
    end
  end

  def self.export!(path)
    validate_storage!
    entries = RetentionAction.unscoped.where(action: %w[erased anonymized deleted]).order(:created_at).map do |action|
      { "organization_id" => action.organization_id, "person_id" => action.person_id,
        "mode" => action.action == "anonymized" ? "anonymize" : "delete" }
    end
    LocalSecurity::Database.write_signed(path, {
      "database" => LocalSecurity::Database.new.name, "exported_at" => Time.now.utc.iso8601, "entries" => entries
    })
  end

  def self.replay!(path)
    database = LocalSecurity::Database.new
    raise LocalSecurity::Error, "Replay requires a new quarantined recovery database" unless database.name.start_with?("bigbuck_recovery_") && !File.exist?(File.join(database.directory, "READY.json"))
    validate_storage!
    ledger = LocalSecurity::Database.read_signed(path)
    source = LocalSecurity::Database.read_signed(File.join(database.directory, "SOURCE.json"))
    exported = Time.iso8601(ledger.fetch("exported_at"))
    unless ledger.fetch("database") == source.fetch("database") && exported >= Time.iso8601(source.fetch("captured_at")) &&
        exported <= Time.now.utc && exported >= Time.now.utc - 300
      raise LocalSecurity::Error, "Recovery needs a fresh erasure ledger from the snapshot source"
    end
    # Restored tasks must not run; only erasure cleanup is invoked synchronously.
    ActiveJob::Base.queue_adapter = :test
    entries = ledger.fetch("entries")
    raise LocalSecurity::Error, "Invalid erasure ledger" unless entries.is_a?(Array)
    entries.each do |entry|
      raise LocalSecurity::Error, "Invalid erasure mode" unless %w[delete anonymize].include?(entry.fetch("mode"))
      person = Person.unscoped.find_by(id: entry.fetch("person_id"))
      next unless person # A person created after the snapshot may be absent.
      raise LocalSecurity::Error, "Erasure tenant mismatch" unless person.organization_id == entry.fetch("organization_id")
      Current.set(organization_id: person.organization_id, actor_id: nil) do
        raise PersonEraser::Held, "legal_hold" if LegalHoldService.person_held?(person.id)
        PersonEraser.call(person: person, mode: entry.fetch("mode")) unless person.erased?
      end
    end
    RetentionAction.unscoped.find_each do |action|
      ErasedDocumentCleanupJob.perform_now(action.id) if Array(action.details["blobs"]).any?
    end
    Person.unscoped.where.not(erased_at: nil).find_each do |person|
      raise LocalSecurity::Error, "Recovery still contains erased personal data" if PersonEraser.verify(person).any?
    end
    puts "Replayed erasures and verified all erased people and storage cleanup."
  ensure
    Current.reset
  end
end
