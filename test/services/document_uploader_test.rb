# frozen_string_literal: true

require "test_helper"

class DocumentUploaderTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "DocCo", slug: "doc-#{SecureRandom.hex(3)}",
      owner_email: "owner-#{SecureRandom.hex(3)}@doc.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    @person = Person.create!(display_name: "Cand")
  end

  teardown { Current.reset }

  test "traversal filenames become opaque storage keys and oversized input is bounded" do
    doc = DocumentUploader.call(person: @person, filename: "../../outside.pdf",
      content_type: "application/pdf", io: StringIO.new("%PDF-1.4 private"))
    assert_equal "outside.pdf", doc.filename
    refute_includes doc.storage_key, "outside"
    refute_includes doc.storage_key, "/"
    io = StringIO.new("%PDF-" + "x" * DocumentUploader::MAX_BYTES)
    assert_no_difference("Document.count") do
      assert_raises(ArgumentError) do
        DocumentUploader.call(person: @person, filename: "large.pdf", content_type: "application/pdf", io: io)
      end
    end
    assert_operator io.pos, :<=, DocumentUploader::MAX_BYTES + 64 * 1024
  end

  test "scanner exit status controls quarantine and erasure blocks downloads" do
    original = ENV["BIGBUCK_CLAMSCAN"]
    Tempfile.create("scanner") do |script|
      path = script.path
      script.close
      ENV["BIGBUCK_CLAMSCAN"] = path
      File.chmod(0700, path)
      [ [ 0, "clean" ], [ 1, "infected" ], [ 2, "failed" ] ].each do |code, expected|
        File.write(path, "#!/bin/sh\nexit #{code}\n")
        doc = DocumentUploader.call(person: @person, filename: "resume.pdf",
          content_type: "application/pdf", io: StringIO.new("%PDF-1.4 private"))
        ScanDocumentJob.perform_now(doc.id)
        assert_equal expected, doc.reload.scan_status
        assert_equal code.zero?, doc.downloadable?
        if code.zero?
          @person.update!(erased_at: Time.current)
          refute doc.downloadable?
          @person.update!(erased_at: nil)
        end
      end
    end
  ensure
    ENV["BIGBUCK_CLAMSCAN"] = original
  end

  test "upload stays unavailable when the scanner is unavailable" do
    original = ENV["BIGBUCK_CLAMSCAN"]
    ENV["BIGBUCK_CLAMSCAN"] = Rails.root.join("tmp", "missing-security-scanner").to_s
    io = StringIO.new("%PDF-1.4 resume")
    doc = nil
    assert_enqueued_with(job: ScanDocumentJob) do
      doc = DocumentUploader.call(
        person: @person,
        filename: "resume.pdf",
        content_type: "application/pdf",
        io: io
      )
    end
    assert_equal "pending", doc.scan_status
    refute doc.downloadable?

    perform_enqueued_jobs
    assert_equal "failed", doc.reload.scan_status
    refute doc.downloadable?
  ensure
    ENV["BIGBUCK_CLAMSCAN"] = original
  end
end
