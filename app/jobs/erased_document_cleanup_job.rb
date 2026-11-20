# frozen_string_literal: true

class ErasedDocumentCleanupJob < ApplicationJob
  self.enqueue_after_transaction_commit = true
  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  def perform(action_id)
    action = RetentionAction.unscoped.find(action_id)
    Array(action.details["blobs"]).each do |entry|
      blob = ActiveStorage::Blob.find_by(id: entry.fetch("id"))
      raise "document_still_attached" if blob&.attachments&.exists?

      # Delete storage before metadata. Active Storage's normal purge destroys
      # the blob row first, which loses retry information on storage failure.
      service = ActiveStorage::Blob.services.fetch(entry.fetch("service_name"))
      service.delete(entry.fetch("key"))
      service.delete_prefixed("variants/#{entry.fetch('key')}/")
      blob&.destroy!
    end
  end
end
