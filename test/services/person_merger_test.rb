# frozen_string_literal: true

require "test_helper"

class PersonMergerTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "MergeCo", slug: "merge-#{SecureRandom.hex(3)}",
      owner_email: "owner-#{SecureRandom.hex(3)}@merge.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id
  end

  teardown { Current.reset }

  test "merge moves contacts and records outbox" do
    a = PersonMatcher.find_or_create(display_name: "A", email: "a@x.test", viewer: @provisioned[:membership]).person
    b = PersonMatcher.find_or_create(display_name: "B", email: "b@x.test", viewer: @provisioned[:membership]).person

    PersonMerger.call(survivor: a, merged: b)

    assert_equal a.id, b.reload.merged_into_id
    assert a.contact_points.reload.where(kind: "email", normalized_value: "b@x.test").exists?
    assert_equal 1, OutboxEvent.where(event_type: "person.merged", resource_id: a.id).count
  end

  test "cross-tenant merge is impossible" do
    other = OrganizationProvisioner.call(
      name: "Other", slug: "other-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@x.test", owner_name: "O"
    )
    Current.organization_id = @provisioned[:organization].id
    a = Person.create!(display_name: "A")

    Current.organization_id = other[:organization].id
    b = Person.create!(display_name: "B")

    assert_raises(ArgumentError) { PersonMerger.call(survivor: a, merged: b) }
  end
end
