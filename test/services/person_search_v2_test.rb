# frozen_string_literal: true

require "test_helper"

class PersonSearchV2Test < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "SearchCo", slug: "s-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@s.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id
    @viewer = @provisioned[:membership]
    @acme = Company.create!(name: "Acme Robotics")
    @ana = person("Ana Staff", "ana@example.com", headline: "Staff backend engineer", current_title: "Staff Engineer", city: "Philadelphia",
      source: "sourced", tags: %w[go infra])
    @ben = person("Ben Senior", "ben@example.com", headline: "Senior backend engineer", current_title: "Senior Engineer", city: "Boston",
      source: "referral", tags: %w[go])
    @cy = person("Cy Staff", "cy@example.com", headline: "Staff frontend engineer", current_title: "Staff Engineer", city: "Philadelphia",
      source: "applied", tags: %w[react])
    PersonAffiliation.create!(person: @ana, company: @acme, current: true, title: "Staff Engineer")
    PersonNote.create!(person: @ben, body: "Loves Kubernetes and mentoring")
  end

  teardown { Current.reset }

  def person(name, email, tags: [], **attrs)
    p = PersonMatcher.find_or_create(display_name: name, email: email, viewer: @viewer).person
    p.update!(attrs)
    tags.each { |t| PersonTagger.add!(person: p, tag: Tag.find_or_create_named!(t)) }
    p
  end

  def names(sort: nil, **filters)
    opts = sort ? { sort: sort } : {}
    PersonSearch.call(viewer: @viewer, filters: filters, **opts).map(&:display_name).sort
  end

  test "the demo query: staff backend, Philadelphia, tag go, not contacted in 90 days" do
    @cy.update!(last_contacted_at: 5.days.ago)
    result = names(q: "staff backend", location: "Philadelphia", tag: "go", not_contacted_days: 90)
    assert_equal [ "Ana Staff" ], result
  end

  test "q words all must match, across name, headline, company, tags and notes" do
    assert_equal [ "Ana Staff", "Cy Staff" ], names(q: "staff")
    assert_equal [ "Ana Staff" ], names(q: "staff backend")
    assert_equal [ "Ana Staff" ], names(q: "acme")
    assert_equal [ "Cy Staff" ], names(q: "react")
    assert_equal [ "Ben Senior" ], names(q: "kubernetes")
    assert_empty names(q: "staff kubernetes")
  end

  test "tag filters need every tag, and not_tag excludes" do
    assert_equal [ "Ana Staff" ], names(tag: "go, infra")
    assert_equal [ "Ana Staff", "Ben Senior" ], names(tag: "GO")
    assert_equal [ "Ben Senior" ], names(tag: "go", not_tag: "infra")
  end

  test "source, engagement, title, company and has_email" do
    assert_equal [ "Ben Senior" ], names(source: "referral")
    assert_equal [ "Ana Staff", "Cy Staff" ], names(source: "sourced,applied")
    @ben.update!(engagement_status: "interested")
    assert_equal [ "Ben Senior" ], names(engagement_status: "interested")
    assert_equal [ "Ana Staff", "Cy Staff" ], names(title: "Staff")
    assert_equal [ "Ana Staff" ], names(company: "Acme")
    @cy.update_columns(primary_email: nil)
    assert_equal [ "Cy Staff" ], names(has_email: false)
  end

  test "recency: never contacted counts as not contacted, recent contact does not" do
    @ana.update!(last_contacted_at: 100.days.ago)
    @ben.update!(last_contacted_at: 3.days.ago)
    assert_equal [ "Ana Staff", "Cy Staff" ], names(not_contacted_days: 90)
    assert_equal [ "Ben Senior" ], names(contacted_within_days: 7)
  end

  test "custom field values filter, but only fields that are internal" do
    field = CustomField.create!(entity: "person", key: "visa", label: "Visa", field_type: "text", data_class: "internal")
    secret = CustomField.create!(entity: "person", key: "salary_band", label: "Band", field_type: "text", data_class: "sensitive")
    [ [ field, "none" ], [ secret, "L7" ] ].each do |f, v|
      CustomFieldValue.create!(custom_field_id: f.id, entity_type: "Person", entity_id: @ana.id, value_text: v)
    end
    assert_equal [ "Ana Staff" ], names(custom: { visa: "none" })
    assert_empty names(custom: { salary_band: "L7" })
  end

  test "relevance puts name hits first; sort and paging are stable" do
    ordered = PersonSearch.call(viewer: @viewer, filters: { q: "staff", sort: "relevance" }).map(&:display_name)
    assert_equal 2, ordered.size
    assert_equal %w[Ana Cy], ordered.map { |n| n.split.first }.sort
    assert_equal [ "Ana Staff", "Ben Senior", "Cy Staff" ], PersonSearch.call(viewer: @viewer, filters: { sort: "name" }).map(&:display_name)
    assert_equal [ "Ben Senior" ], PersonSearch.call(viewer: @viewer, filters: { sort: "name" }, limit: 1, offset: 1).map(&:display_name)
    assert_equal 3, PersonSearch.count(viewer: @viewer)
  end

  test "like wildcards in the query are literal" do
    assert_empty names(q: "%")
    assert_empty names(q: "_")
  end
end
