# frozen_string_literal: true

require "test_helper"

# M8 proving test: CSV import with mapping/provenance; webhook consumer and sync client converge.
class M8IntegrationsTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "IntCo", slug: "in-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@in.test", owner_name: "O"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id
  end

  teardown { Current.reset }

  test "csv import and webhook/sync consumers converge" do
    fake_http = WebhookDispatcher::FakeHttp.new
    WebhookDispatcher.http_client = fake_http
    WebhookEndpoint.create!(
      key: "warehouse", url: "https://hooks.example.test/events",
      secret_ref: "whsec_test", event_types: %w[person.created person.updated]
    )

    csv = <<~CSV
      id,name,email,phone
      SRC-1,Ada Lovelace,ada@in.test,+15550001
      SRC-2,Alan Turing,alan@in.test,+15550002
    CSV

    result = CsvPeopleImporter.call(
      csv_string: csv,
      field_mapping: { "id" => "source_id", "name" => "display_name", "email" => "primary_email", "phone" => "primary_phone" },
      source_system: "greenhouse_export"
    )
    assert_equal "applied", result.run.status
    assert_equal 2, result.run.created_count
    assert result.people.all? { |p| p.source_system == "greenhouse_export" }
    assert result.run.import_rows.all? { |r| r.source_id.present? && r.resource_id.present? }

    deliveries = WebhookDispatcher.drain!
    assert deliveries.any?
    webhook_person_ids = fake_http.person_ids_from_created.sort

    sync = SyncFeed.people
    sync_person_ids = sync["data"].map { |row| row["id"] }.sort
    sync_emails = sync["data"].map { |row| row["primary_email"] }.sort

    assert_equal webhook_person_ids, sync_person_ids & webhook_person_ids
    assert_equal %w[ada@in.test alan@in.test], sync_emails
    # Re-import updates same source ids (provenance stable)
    again = CsvPeopleImporter.call(
      csv_string: csv.sub("Ada Lovelace", "Ada L."),
      field_mapping: { "id" => "source_id", "name" => "display_name", "email" => "primary_email", "phone" => "primary_phone" },
      source_system: "greenhouse_export"
    )
    assert_equal 2, again.run.updated_count
    assert_equal 1, Person.where(source_system: "greenhouse_export", source_id: "SRC-1").count
  ensure
    WebhookDispatcher.http_client = nil
  end

  test "repository lock blocks config writes without break glass" do
    org = @provisioned[:organization]
    org.update!(repository_lock: true)
    assert_raises(RepositoryLock::Locked) { RepositoryLock.ensure_writable! }

    session = RepositoryLock.open_break_glass!(reason: "pipeline emergency", for_duration: 1.hour)
    assert session.open?
    assert RepositoryLock.ensure_writable!
  end

  test "google sign-in requires verified domain" do
    assert_raises(GoogleSignIn::DomainNotVerified) do
      GoogleSignIn.allow?(email: "user@acme.example")
    end
    GoogleSignIn.verify_domain!(domain: "acme.example")
    assert GoogleSignIn.allow?(email: "user@acme.example")
  end
end
