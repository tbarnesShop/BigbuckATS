# frozen_string_literal: true

require "test_helper"

# M9b: append-only audit, keyed hashing, data-class registry, and an audit row
# for every tenant write, not only the ones that go through ChangeWriter.
class AuditHardeningTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "Audit Co", slug: "audit-#{SecureRandom.hex(4)}",
      owner_email: "owner-#{SecureRandom.hex(4)}@audit.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    Current.organization_id = @org.id
    Current.actor_id = @provisioned[:user].id
    Current.actor_type = "user"
    Current.request_id = "req-audit"
  end

  teardown { Current.reset }

  test "every database column has a valid data class" do
    assert_empty DataClasses.unclassified, "classify these in config/data_classes.yml"
    assert_empty DataClasses.invalid_entries
  end

  test "audit rows cannot be updated or deleted" do
    row = ChangeWriter.call(record: Company.new(name: "Initech"), action: "company.created", event_type: "company.created").audit_event

    assert_raises(ActiveRecord::StatementInvalid) { row.update_columns(action: "tampered") }
    assert_raises(ActiveRecord::StatementInvalid) { AuditEvent.where(id: row.id).delete_all }
    assert_equal "company.created", AuditEvent.find(row.id).action
  end

  test "a direct model write still leaves an audit row" do
    company = Company.create!(name: "Direct Write Ltd")

    audit = AuditEvent.where(resource_type: "Company", resource_id: company.id).sole
    assert_equal "company.created", audit.action
    assert_equal @provisioned[:user].id, audit.actor_id
    assert_equal "Direct Write Ltd", audit.change_set["name"].last, "internal values are kept as-is"
    assert_equal "system", audit.source_surface
  end

  test "a ChangeWriter write is audited once, not twice" do
    company = ChangeWriter.call(record: Company.new(name: "Once Inc"), action: "company.created", event_type: "company.created").record
    assert_equal 1, AuditEvent.where(resource_id: company.id).count
  end

  test "personal values are keyed hashes salted by organization" do
    person = Person.create!(display_name: "Grace Hopper", primary_email: "grace@example.com")
    change_set = AuditEvent.where(resource_type: "Person", resource_id: person.id).sole.change_set

    assert_equal AuditHasher.digest(@org.id, "grace@example.com"), change_set["primary_email"].last
    refute_equal Digest::SHA256.hexdigest("grace@example.com"), change_set["primary_email"].last
    refute_includes change_set.to_json, "grace@example.com"
    refute_equal AuditHasher.digest(Id.generate, "grace@example.com"), AuditHasher.digest(@org.id, "grace@example.com")
  end

  test "secrets never reach audit history" do
    endpoint = WebhookEndpoint.create!(key: "hook", url: "https://hooks.test/x", secret_ref: "s3cr3t-value")
    audit = AuditEvent.where(resource_type: "WebhookEndpoint", resource_id: endpoint.id).sole
    refute audit.change_set.key?("secret_ref")
    refute_includes audit.change_set.to_json, "s3cr3t-value"
  end

  test "custom field values follow their field's data class" do
    pii_field = CustomField.create!(entity: "person", key: "nickname", label: "Nickname", field_type: "text", data_class: "pii")
    open_field = CustomField.create!(entity: "person", key: "team", label: "Team", field_type: "text", data_class: "internal")
    person = Person.create!(display_name: "Field Person")

    pii_value = CustomFieldValue.create!(custom_field: pii_field, entity_type: "Person", entity_id: person.id, value_text: "Gigi")
    open_value = CustomFieldValue.create!(custom_field: open_field, entity_type: "Person", entity_id: person.id, value_text: "Platform")

    pii_audit = AuditEvent.where(resource_id: pii_value.id).sole.change_set
    open_audit = AuditEvent.where(resource_id: open_value.id).sole.change_set
    assert_equal AuditHasher.digest(@org.id, "Gigi"), pii_audit["value_text"].last
    assert_equal "Platform", open_audit["value_text"].last
  end

  test "an unclassified column fails the audit write instead of leaking" do
    fake = Class.new do
      def self.table_name = "people"
      def self.column_names = %w[id brand_new_column]
    end
    assert_raises(DataClasses::Unclassified) do
      AuditRecorder.redact(fake.new, { "brand_new_column" => [ nil, "x" ] }, @org.id)
    end
  end

  test "a synthetic change key that is not a column is hashed, not stored" do
    redacted = AuditRecorder.redact(Person.new, { "merged_id" => [ nil, "p-123" ] }, @org.id)
    assert_equal [ nil, AuditHasher.digest(@org.id, "p-123") ], redacted["merged_id"]
  end

  test "outbox events carry api version, actor and surface" do
    Current.source_surface = "cli"
    outbox = ChangeWriter.call(record: Company.new(name: "Evented"), action: "company.created", event_type: "company.created").outbox_event
    assert_equal "2026-11-01", outbox.api_version
    assert_equal "user", outbox.actor_type
    assert_equal @provisioned[:user].id, outbox.actor_id
    assert_equal "cli", outbox.source_surface
  end
end
