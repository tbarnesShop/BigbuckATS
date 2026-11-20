# frozen_string_literal: true

require "tempfile"

class DocumentUploader
  MAX_BYTES = 10 * 1024 * 1024
  TYPES = %w[application/pdf text/plain application/vnd.openxmlformats-officedocument.wordprocessingml.document].freeze

  def self.call(person:, filename:, content_type:, io:, replace: false)
    raise ArgumentError, "unsupported file type" unless TYPES.include?(content_type)
    raise ArgumentError, "tenant mismatch" unless person.organization_id == Current.organization_id
    safe_name = File.basename(filename.to_s.tr("\\", "/")).gsub(/[[:cntrl:]]/, "").first(255)
    raise ArgumentError, "filename required" if safe_name.blank?
    blob = nil
    Tempfile.create([ "bigbuck-upload", ".quarantine" ], binmode: true) do |file|
      size = 0
      digest = Digest::SHA256.new
      while (chunk = io.read(64 * 1024)) && !chunk.empty?
        size += chunk.bytesize
        raise ArgumentError, "file too large" if size > MAX_BYTES
        digest.update(chunk)
        file.write(chunk)
      end
      raise ArgumentError, "empty file" if size.zero?
      file.rewind
      prefix = file.read(8)
      valid = case content_type
      when "application/pdf" then prefix.start_with?("%PDF-")
      when "text/plain" then !prefix.include?("\0")
      else prefix.start_with?("PK\x03\x04")
      end
      raise ArgumentError, "file type mismatch" unless valid
      file.rewind
      blob = ActiveStorage::Blob.create_and_upload!(io: file, filename: safe_name, content_type: content_type, identify: false)
      person.with_lock do
        previous = replace ? person.documents.where(superseded_at: nil).to_a : []
        doc = Document.create!(person: person, filename: safe_name, content_type: content_type,
          byte_size: size, checksum: digest.hexdigest, storage_key: blob.key, scan_status: "pending")
        doc.file.attach(blob)
        previous.each { |old| old.update!(superseded_at: Time.current) }
        ScanDocumentJob.perform_later(doc.id)
        doc
      end
    end
  rescue StandardError
    blob&.purge_later
    raise
  end
end
