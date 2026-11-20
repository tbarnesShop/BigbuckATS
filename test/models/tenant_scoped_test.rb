# frozen_string_literal: true

require "test_helper"

class TenantScopedTest < ActiveSupport::TestCase
  setup do
    @org_a = Organization.create!(name: "A", slug: "a-#{SecureRandom.hex(4)}")
    @org_b = Organization.create!(name: "B", slug: "b-#{SecureRandom.hex(4)}")

    Current.organization_id = @org_a.id
    @person_a = ChangeWriter.call(
      record: Person.new(display_name: "In A", lifecycle_stage: "prospect", visibility: "public"),
      action: "person.created",
      event_type: "person.created"
    ).record

    Current.organization_id = @org_b.id
    @person_b = ChangeWriter.call(
      record: Person.new(display_name: "In B", lifecycle_stage: "prospect", visibility: "public"),
      action: "person.created",
      event_type: "person.created"
    ).record
  end

  teardown { Current.reset }

  test "queries are scoped to the current organization" do
    Current.organization_id = @org_a.id
    assert_equal [ @person_a.id ], Person.pluck(:id)
    assert_nil Person.find_by(id: @person_b.id)
  end

  test "unset tenant returns no rows (fail closed)" do
    Current.organization_id = nil
    assert_empty Person.all
  end

  test "cross-tenant find is invisible" do
    Current.organization_id = @org_a.id
    assert_raises(ActiveRecord::RecordNotFound) { Person.find(@person_b.id) }
  end

  test "composite tenant uniqueness exists on people" do
    indexes = ActiveRecord::Base.connection.indexes("people")
    tenant_pk = indexes.find { |i| i.unique && i.columns == %w[organization_id id] }
    assert tenant_pk, "expected unique index on (organization_id, id)"
  end
end
