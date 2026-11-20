# frozen_string_literal: true

require "test_helper"

class PersonMatcherTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "Acme", slug: "acme-#{SecureRandom.hex(3)}",
      owner_email: "owner-#{SecureRandom.hex(3)}@acme.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    Current.organization_id = @org.id
    @membership = @provisioned[:membership]
  end

  teardown { Current.reset }

  test "exact email attaches without overwriting display name" do
    first = PersonMatcher.find_or_create(
      display_name: "Ada Lovelace", email: "ada@example.com", viewer: @membership
    )
    ChangeWriter.call(record: first.person, action: "person.created", event_type: "person.created") unless first.attached

    second = PersonMatcher.find_or_create(
      display_name: "A. Lovelace", email: "ada@example.com", phone: "555-0100", viewer: @membership
    )

    assert second.attached
    assert_equal first.person.id, second.person.id
    assert_equal "Ada Lovelace", second.person.reload.display_name
    assert second.person.contact_points.where(kind: "phone").exists?
  end

  test "phone match creates a merge suggestion not an attach" do
    a = PersonMatcher.find_or_create(display_name: "A", phone: "5551111", viewer: @membership)
    ChangeWriter.call(record: a.person, action: "person.created", event_type: "person.created") unless a.attached

    b = PersonMatcher.find_or_create(display_name: "B", phone: "555-1111", viewer: @membership)
    refute b.attached
    refute_equal a.person.id, b.person.id
    assert MergeSuggestion.exists?(status: "open")
  end

  test "employee only attaches on verified email" do
    person = Person.create!(display_name: "Emp", lifecycle_stage: "employee", primary_email: "e@acme.test")
    PersonContactPoint.create!(person: person, kind: "email", value: "e@acme.test", verified: false, primary: true)

    result = PersonMatcher.find_or_create(display_name: "Other", email: "e@acme.test", viewer: @membership)
    refute result.attached
    assert result.held_duplicate
  end

  test "hidden person collision stays quiet" do
    hidden = Person.create!(display_name: "Secret", visibility: "restricted", primary_email: "s@x.test")
    PersonContactPoint.create!(person: hidden, kind: "email", value: "s@x.test", primary: true)

    recruiter_role = Role.find_by!(key: "recruiter")
    recruiter = User.create!(email: "rec-#{SecureRandom.hex(3)}@acme.test", name: "Rec")
    membership = Membership.create!(user: recruiter, role: recruiter_role, status: "active")

    result = PersonMatcher.find_or_create(display_name: "New", email: "s@x.test", viewer: membership)
    refute result.attached
    assert result.held_duplicate
    assert_not_equal hidden.id, result.person.id
    # Recruiter without read_restricted cannot see the merge suggestion involving hidden
    refute PersonVisibility.can_see_both?(hidden, result.person, viewer: membership)
  end
end
