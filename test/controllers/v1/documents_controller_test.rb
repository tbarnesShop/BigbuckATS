# frozen_string_literal: true

require "test_helper"

class V1::DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @old_header_auth = Rails.configuration.x.header_auth
    Rails.configuration.x.header_auth = false
    data = OrganizationProvisioner.call(name: "Documents", slug: "documents-#{SecureRandom.hex(5)}",
      owner_email: "documents-#{SecureRandom.hex(5)}@example.test", owner_name: "Owner")
    @org = data[:organization]
    Current.organization_id = @org.id
    @person = Person.create!(display_name: "Candidate")
    @other_person = Person.create!(display_name: "Other candidate")
    @document = DocumentUploader.call(person: @person, filename: "resume.pdf", content_type: "application/pdf",
      io: StringIO.new("%PDF-1.4 test resume"))
    @document.update!(scan_status: "clean")
    @headers = bearer(CredentialIssuer.call(kind: "session", name: "Document test", user: data[:user],
      expires_at: 1.hour.from_now, audit: false).token)
    @reader = User.create!(email: "reader-#{SecureRandom.hex(5)}@example.test", name: "Reader")
    @role = Role.create!(key: "reader-#{SecureRandom.hex(5)}", name: "Reader")
    @role.grant!("person.read")
    Membership.create!(user: @reader, role: @role, status: "active")
    @reader_headers = bearer(CredentialIssuer.call(kind: "session", name: "Reader", user: @reader,
      expires_at: 1.hour.from_now, audit: false).token)
    Current.reset
  end

  teardown do
    Current.set(organization_id: @org.id) { @person.documents.each { |document| document.file.purge } }
    Rails.configuration.x.header_auth = @old_header_auth
    Current.reset
  end

  test "metadata does not expose storage and file responses support inline and download" do
    get "/v1/people/#{@person.id}/documents", headers: @headers
    assert_response :success
    row = response.parsed_body.fetch("data").first
    assert_equal "resume.pdf", row.fetch("filename")
    assert_equal true, row.fetch("downloadable")
    assert_nil row["storage_key"]
    assert_nil row["checksum"]
    assert_nil row["url"]
    get file_path, headers: @headers
    assert_response :success
    assert_equal "%PDF-1.4 test resume", response.body
    assert_equal "application/pdf", response.media_type
    assert_match(/inline/, response.headers["Content-Disposition"])
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    get "#{file_path}?download=true", headers: @headers
    assert_response :success
    assert_match(/attachment/, response.headers["Content-Disposition"])
  end

  test "document permission and person visibility apply to metadata and file bytes" do
    get "/v1/people/#{@person.id}/documents", headers: @reader_headers
    assert_response :forbidden
    get file_path, headers: @reader_headers
    assert_response :forbidden
    Current.set(organization_id: @org.id) do
      @role.grant!("document.read")
      @person.update!(visibility: "restricted")
    end
    get "/v1/people/#{@person.id}/documents", headers: @reader_headers
    assert_response :not_found
    get file_path, headers: @reader_headers
    assert_response :not_found
    get "/v1/people/#{@other_person.id}/documents/#{@document.id}", headers: @headers
    assert_response :not_found
    other = OrganizationProvisioner.call(name: "Other org", slug: "other-doc-#{SecureRandom.hex(5)}",
      owner_email: "other-doc-#{SecureRandom.hex(5)}@example.test", owner_name: "Other")
    Current.organization_id = other[:organization].id
    token = CredentialIssuer.call(kind: "session", name: "Other", user: other[:user], expires_at: 1.hour.from_now, audit: false).token
    Current.reset
    get file_path, headers: bearer(token)
    assert_response :not_found
  end

  test "quarantined, unattached and erased files stay unavailable" do
    %w[pending infected failed].each do |status|
      Current.set(organization_id: @org.id) { @document.update!(scan_status: status) }
      get file_path, headers: @headers
      assert_response :not_found
    end
    Current.set(organization_id: @org.id) do
      @document.update!(scan_status: "clean")
      @person.update!(erased_at: Time.current)
    end
    get file_path, headers: @headers
    assert_response :not_found
    Current.set(organization_id: @org.id) do
      @person.update!(erased_at: nil)
      @document.file.detach
    end
    get file_path, headers: @headers
    assert_response :not_found
  end

  test "replacement retains history, quarantines the new resume and is idempotent" do
    file = Tempfile.new([ "replacement", ".pdf" ])
    file.write("%PDF-1.4 replacement")
    file.close
    headers = @headers.merge("Idempotency-Key" => "replacement-test")
    2.times do
      post "/v1/people/#{@person.id}/documents", headers: headers,
        params: { file: Rack::Test::UploadedFile.new(file.path, "application/pdf", original_filename: "replacement.pdf") }
      assert_response :created
    end
    Current.set(organization_id: @org.id) do
      assert_equal 2, @person.documents.count
      assert_not_nil @document.reload.superseded_at
      assert @document.file.attached?
    end
    get "/v1/people/#{@person.id}/documents", headers: @headers
    rows = response.parsed_body.fetch("data")
    assert_equal [ "replacement.pdf" ], rows.map { |row| row["filename"] }
    assert_equal "pending", rows.first["scan_status"]
    refute rows.first["downloadable"]
  ensure
    file&.unlink
  end

  test "invalid replacement and denied or hidden uploads preserve the current resume" do
    post "/v1/people/#{@person.id}/documents", headers: @headers, as: :json,
      params: { document: { filename: "wrong.pdf", content_type: "application/pdf", content_base64: Base64.strict_encode64("not a PDF") } }
    assert_response :unprocessable_entity
    Current.set(organization_id: @org.id) { assert_nil @document.reload.superseded_at }
    input = { document: { filename: "resume.txt", content_type: "text/plain", content_base64: Base64.strict_encode64("Resume") } }
    post "/v1/people/#{@person.id}/documents", headers: @reader_headers, params: input, as: :json
    assert_response :forbidden
    Current.set(organization_id: @org.id) do
      @role.grant!("document.upload")
      @person.update!(visibility: "restricted")
    end
    post "/v1/people/#{@person.id}/documents", headers: @reader_headers, params: input, as: :json
    assert_response :not_found
    Current.set(organization_id: @org.id) { assert_equal 1, @person.documents.count }
  end

  private

  def bearer(token) = { "Authorization" => "Bearer #{token}" }
  def file_path = "/v1/people/#{@person.id}/documents/#{@document.id}"
end
