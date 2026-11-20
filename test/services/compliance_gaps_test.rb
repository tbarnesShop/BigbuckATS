# frozen_string_literal: true

require "test_helper"

# M9f: erasure reaches every place a person's data lands, and compliance work
# is available through the API.
class ComplianceGapsTest < ActionDispatch::IntegrationTest
  setup do
    @header_auth_was = Rails.configuration.x.header_auth
    Rails.configuration.x.header_auth = false
    @provisioned = OrganizationProvisioner.call(
      name: "Comply Co", slug: "comply-#{SecureRandom.hex(4)}",
      owner_email: "owner-#{SecureRandom.hex(4)}@comply.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @owner = @provisioned[:user]
    within_org do
      @person = PersonMatcher.find_or_create(display_name: "Sam Subject", email: "sam@comply.test",
                                             viewer: @provisioned[:membership]).person
      ConsentPurpose.create!(key: "talent-pool", label: "Talent pool", lawful_basis: "consent")
      @token = CredentialIssuer.call(kind: "personal", name: "p", user: @owner, scopes: Scopes::ALL, audit: false).token
    end
  end

  teardown do
    Rails.configuration.x.header_auth = @header_auth_was
    Current.reset
  end

  test "erasure clears custom field values, files, import rows and cached responses" do
    file_path = nil
    within_org do
      CustomFieldDefinitions.create!(entity: "person", key: "nickname", label: "Nickname", field_type: "text", data_class: "pii")
      CustomFieldValues.write!(entity_type: "Person", entity_id: @person.id, key: "nickname", value: "Sammy")
      doc = DocumentUploader.call(person: @person, filename: "sam-resume.pdf", content_type: "application/pdf",
                                  io: StringIO.new("%PDF-1.4 resume"))
      file_path = Pathname.new(ActiveStorage::Blob.service.send(:path_for, doc.file.blob.key))
      assert File.exist?(file_path)
      CsvPeopleImporter.call(csv_string: "id,name,email\nX1,Sam Subject,sam@comply.test\n", source_system: "old_ats")
      IdempotencyKey.create!(key: "k1", request_path: "/v1/people", request_method: "POST", response_status: 201,
                             response_body: { "id" => @person.id, "primary_email" => "sam@comply.test" })
    end

    post "/v1/people/#{@person.id}/erase", headers: bearer, as: :json
    assert_response :success
    assert_includes response.parsed_body["verify"], "file_cleanup_pending"
    within_org do
      ErasedDocumentCleanupJob.perform_now(RetentionAction.where(person_id: @person.id).last.id)
      assert_empty PersonEraser.verify(@person)
    end

    within_org do
      assert_nil CustomFieldValue.find_by(entity_id: @person.id).value_text
      refute File.exist?(file_path), "the uploaded file is deleted"
      assert_equal "erased", Document.find_by(person_id: @person.id).filename
      assert ImportRow.where(resource_id: @person.id).all? { |r| r.raw.nil? && r.mapped.nil? }
      refute IdempotencyKey.exists?(key: "k1")
    end
  end

  test "data requests: access returns the packet, erasure respects legal holds" do
    post "/v1/data_requests", params: { kind: "access", person_id: @person.id, requester_email: "sam@comply.test" },
                              headers: bearer, as: :json
    assert_response :created
    access_id = response.parsed_body["id"]
    assert response.parsed_body["due_at"].present?

    post "/v1/data_requests/#{access_id}/complete", headers: bearer, as: :json
    assert_response :success
    assert_equal "completed", response.parsed_body["status"]
    assert_equal @person.id, response.parsed_body.dig("result", "person", "id")
    assert response.parsed_body.dig("result").key?("custom_fields")

    post "/v1/legal_holds", params: { subject_type: "person", subject_id: @person.id, reason: "litigation" },
                            headers: bearer, as: :json
    assert_response :created
    hold_id = response.parsed_body["id"]

    post "/v1/data_requests", params: { kind: "erasure", person_id: @person.id, requester_email: "sam@comply.test" },
                              headers: bearer, as: :json
    erasure_id = response.parsed_body["id"]
    post "/v1/data_requests/#{erasure_id}/complete", headers: bearer, as: :json
    assert_response :forbidden
    assert_equal "legal_hold", response.parsed_body["code"]

    post "/v1/legal_holds/#{hold_id}/release", headers: bearer, as: :json
    assert_response :success
    post "/v1/data_requests/#{erasure_id}/complete", headers: bearer, as: :json
    assert_response :success
    assert within_org { @person.reload.erased? }
  end

  test "consents are recorded as new rows and listed newest first" do
    post "/v1/people/#{@person.id}/consents", params: { purpose_key: "talent-pool", status: "granted" }, headers: bearer, as: :json
    assert_response :created
    post "/v1/people/#{@person.id}/consents", params: { purpose_key: "talent-pool", status: "withdrawn" }, headers: bearer, as: :json
    assert_response :created

    get "/v1/people/#{@person.id}/consents", headers: bearer
    assert_equal %w[withdrawn granted], response.parsed_body["data"].map { |c| c["status"] }
  end

  test "the access packet export needs person.export and is audited" do
    limited = within_org { CredentialIssuer.call(kind: "personal", name: "r", user: @owner, scopes: %w[people:read], audit: false).token }
    get "/v1/people/#{@person.id}/access_packet", headers: bearer(limited)
    assert_response :forbidden

    get "/v1/people/#{@person.id}/access_packet", headers: bearer
    assert_response :success
    assert within_org { AuditEvent.exists?(resource_id: @person.id, action: "person.access_exported") }
  end

  test "GraphQL exposes consents, legal holds and data requests" do
    query = <<~GQL
      mutation {
        placeLegalHold(input: { subjectType: "person", subjectId: "#{@person.id}", reason: "audit" }) {
          legalHold { active subjectId } userErrors { code }
        }
        openDataRequest(input: { kind: "access", requesterEmail: "sam@comply.test", personId: "#{@person.id}" }) {
          dataRequest { kind status } userErrors { code }
        }
      }
    GQL
    post "/graphql", params: { query: query }, headers: bearer, as: :json
    data = response.parsed_body["data"]
    assert data.dig("placeLegalHold", "legalHold", "active")
    assert_equal "open", data.dig("openDataRequest", "dataRequest", "status")

    post "/graphql", params: { query: "{ legalHolds { subjectId } dataRequests(first: 5) { nodes { kind } } person(id: \"#{@person.id}\") { consents { status } } }" },
                     headers: bearer, as: :json
    assert_equal [ @person.id ], response.parsed_body.dig("data", "legalHolds").map { |h| h["subjectId"] }
    assert_equal [ "access" ], response.parsed_body.dig("data", "dataRequests", "nodes").map { |n| n["kind"] }
  end

  private

  def bearer(token = @token) = { "Authorization" => "Bearer #{token}" }

  def within_org
    Current.organization_id = @org.id
    Current.actor_id = @owner.id
    yield
  ensure
    Current.reset
  end
end
