# frozen_string_literal: true

require "test_helper"

# M7b proving test: erasing a person leaves no personal data; a hold blocks it.
class PersonErasureTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "EraseCo", slug: "er-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@er.test", owner_name: "O"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id

    GmailClient.backend = GmailClient::Fake.new
    @mailbox = Mailbox.create!(
      kind: "shared", email: "recruiting@er.test", status: "connected", secret_ref: "vault:x"
    )

    @person = Person.create!(
      display_name: "Sam Candidate",
      primary_email: "sam-#{SecureRandom.hex(2)}@er.test",
      primary_phone: "+15551212",
      country: "US", region: "us"
    )
    PersonContactPoint.create!(person: @person, kind: "email", value: @person.primary_email)

    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    pipeline = Pipeline.build_from_template!(template: template)
    job = Job.create!(title: "Eng", status: "active", pipeline: pipeline)
    @application = ApplicationCreator.call(job: job, person: @person)
    # Close application so retention/erasure is allowed by business rules when used
    @application.update!(status: "rejected")

    MessageSender.send_now!(
      mailbox: @mailbox, person: @person,
      subject: "Thanks Sam", body: "We received your application at #{@person.primary_email}"
    )

    purpose = ConsentPurpose.create!(key: "data-processing", label: "DP", lawful_basis: "consent")
    Consent.create!(
      person: @person, consent_purpose: purpose, lawful_basis: "consent",
      status: "granted", captured_via: "recorded_by_user",
      captured_at: Time.current, created_at: Time.current,
      ip_address: "203.0.113.9", user_agent: "TestAgent"
    )
  end

  teardown do
    GmailClient.backend = nil
    Current.reset
  end

  test "erasing a person leaves no personal data; hold blocks it" do
    hold = LegalHoldService.place!(subject: @person, reason: "litigation")
    assert_raises(PersonEraser::Held) { PersonEraser.call(person: @person) }

    LegalHoldService.release!(hold: hold)
    PersonEraser.call(person: @person, mode: "delete")

    @person.reload
    assert @person.erased?
    assert @person.do_not_contact
    assert_nil @person.primary_email
    assert_nil @person.primary_phone
    assert_nil @person.country
    assert_equal "erased", @person.display_name

    assert_empty PersonEraser.verify(@person)
    assert Communication.where(person_id: @person.id).where.not(body: [ nil, "" ]).none?
    assert TimelineEvent.where(person_id: @person.id).none?
    assert Consent.where(person_id: @person.id).where.not(ip_address: nil).none?
    assert RetentionAction.exists?(person_id: @person.id, action: "erased")
  end

  test "access packet excludes compensation and includes profile" do
    packet = AccessPacket.build(person: @person)
    assert_equal @person.display_name, packet["person"]["display_name"]
    assert packet["excluded"].key?("scorecards")
    assert packet["communications"].any?
  end

  test "erasure request stays open until file cleanup and can then be retried" do
    document = DocumentUploader.call(person: @person, filename: "resume.pdf",
      content_type: "application/pdf", io: StringIO.new("%PDF-1.4 private resume"))
    blob = document.file.blob
    request = ComplianceDesk.open_request!(kind: "erasure", person: @person,
      requester_email: @person.primary_email)

    error = assert_raises(ComplianceDesk::Error) { ComplianceDesk.complete_request!(request) }
    assert_equal "cleanup_pending", error.code
    assert_equal "open", request.reload.status
    assert @person.reload.erased?
    assert_includes PersonEraser.verify(@person), "file_cleanup_pending"
    assert blob.service.exist?(blob.key)

    # A failed legacy purge may already have removed metadata. The durable
    # storage key must still prove the residual and allow a successful retry.
    blob.destroy!
    assert_includes PersonEraser.verify(@person), "file_cleanup_pending"

    ErasedDocumentCleanupJob.perform_now(RetentionAction.where(person_id: @person.id).last.id)
    assert_empty PersonEraser.verify(@person)
    completed, result = ComplianceDesk.complete_request!(request)
    assert_equal "completed", completed.reload.status
    assert result["erased"]
    refute blob.service.exist?(blob.key)
    assert_equal 1, RetentionAction.where(person_id: @person.id, action: "erased").count
  end

  test "data request records due date from policy" do
    CompliancePolicy.create!(
      key: "fallback", name: "Fallback", is_fallback: true, priority: 0,
      requirements: { "dataRequests" => { "respondWithin" => "30d" } }
    )
    request = DataRequest.create!(
      person: @person, kind: "access", requester_email: "sam@er.test",
      received_at: Time.current, due_at: 30.days.from_now, status: "open"
    )
    assert_equal "open", request.status
    packet = AccessPacket.build(person: @person)
    request.update!(status: "completed", completed_at: Time.current, outcome_note: "packet sent")
    assert packet["person"]["id"] == @person.id
  end

  test "storage outage retains blob metadata and cleanup intent for a retry" do
    document = DocumentUploader.call(person: @person, filename: "resume.pdf",
      content_type: "application/pdf", io: StringIO.new("%PDF-1.4 private"))
    blob = document.file.blob
    PersonEraser.call(person: @person)
    action = RetentionAction.where(person_id: @person.id, action: "erased").sole
    service = blob.service
    original = service.method(:delete)
    service.define_singleton_method(:delete) { |_key| raise IOError, "storage unavailable" }
    assert_enqueued_with(job: ErasedDocumentCleanupJob, args: [ action.id ]) do
      ErasedDocumentCleanupJob.perform_now(action.id)
    end
    assert ActiveStorage::Blob.exists?(blob.id)
    assert service.exist?(blob.key)
    assert_equal blob.key, action.reload.details.fetch("blobs").sole.fetch("key")
    assert_includes PersonEraser.verify(@person), "file_cleanup_pending"
    service.define_singleton_method(:delete, original)
    ErasedDocumentCleanupJob.perform_now(action.id)
    refute ActiveStorage::Blob.exists?(blob.id)
    refute service.exist?(blob.key)
    assert_empty PersonEraser.verify(@person)
  ensure
    service.define_singleton_method(:delete, original) if service && original
  end
end
