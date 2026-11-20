# frozen_string_literal: true

# Only the old quarantine layout is eligible. Unsafe legacy paths require
# operator review; erasure never follows a supplied filename outside storage.
class LegacyDocumentCleanupJob < ApplicationJob
  self.enqueue_after_transaction_commit = true
  retry_on StandardError, wait: :polynomially_longer, attempts: 10
  def perform(organization_id, key)
    raise ArgumentError, "unsafe_legacy_storage_key" unless key.match?(%r{\Aquarantine/#{Regexp.escape(organization_id)}/[a-zA-Z0-9-]+/[^/\\]+\z})
    root = Rails.root.join("storage").realpath
    path = root.join(key)
    return unless path.exist?
    raise ArgumentError, "unsafe_legacy_storage_path" unless path.realpath.to_s.start_with?(root.to_s + "/")
    File.delete(path)
  end
end
