# frozen_string_literal: true

class ScanDocumentJob < ApplicationJob
  queue_as :documents
  def perform(document_id)
    doc = Document.unscoped.find(document_id)
    Current.set(organization_id: doc.organization_id) do
      return unless doc.scan_status.in?(%w[pending failed]) && !doc.person.erased?
      status = "failed"
      doc.file.blob.open { |file| status = DocumentScanner.call(file.path) } if doc.file.attached?
      doc.update!(scan_status: status)
    end
  end
end
