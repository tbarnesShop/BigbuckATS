# frozen_string_literal: true

require "test_helper"

class ChangeWriterTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(name: "Acme", slug: "acme-#{SecureRandom.hex(4)}")
    Current.organization_id = @org.id
    Current.actor_id = Id.generate
    Current.actor_type = "user"
    Current.request_id = "req_test"
  end

  # Person model gained required defaults in M1; display_name alone still works.

  teardown do
    Current.reset
  end

  test "a write produces exactly one audit row and one outbox event in the same transaction" do
    person = Person.new(display_name: "Ada Lovelace")

    result = ChangeWriter.call(
      record: person,
      action: "person.created",
      event_type: "person.created",
      payload: { "display_name" => "Ada Lovelace" },
      changes: { "display_name" => [ nil, "Ada Lovelace" ] }
    )

    assert result.record.persisted?
    assert_equal 1, AuditEvent.where(resource_id: result.record.id).count
    assert_equal 1, OutboxEvent.where(resource_id: result.record.id).count
    assert_equal "person.created", result.audit_event.action
    assert_equal "person.created", result.outbox_event.event_type
    # PII is a keyed, org-salted hash in audit; never the value or a plain SHA-256
    hashed = result.audit_event.change_set["display_name"].last
    assert_equal AuditHasher.digest(@org.id, "Ada Lovelace"), hashed
    refute_equal Digest::SHA256.hexdigest("Ada Lovelace"), hashed
    assert_equal "2026-11-01", result.audit_event.api_version
    assert_equal result.audit_event.actor_type, result.outbox_event.actor_type
  end

  test "rolls back audit and outbox when the domain write fails" do
    person = Person.new(display_name: nil)

    assert_raises(ActiveRecord::RecordInvalid) do
      ChangeWriter.call(record: person, action: "person.created", event_type: "person.created")
    end

    assert_equal 0, AuditEvent.unscoped.where(organization_id: @org.id).count
    assert_equal 0, OutboxEvent.unscoped.where(organization_id: @org.id).count
  end
end
