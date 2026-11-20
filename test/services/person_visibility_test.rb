# frozen_string_literal: true

require "test_helper"

class PersonVisibilityTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "VisCo", slug: "vis-#{SecureRandom.hex(3)}",
      owner_email: "owner-#{SecureRandom.hex(3)}@vis.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    @owner = @provisioned[:membership]

    dept = Dimension.find_by!(key: "department")
    @eng = DimensionValue.create!(dimension: dept, key: "engineering", label: "Engineering")
    @sales = DimensionValue.create!(dimension: dept, key: "sales", label: "Sales")

    recruiter_role = Role.find_by!(key: "recruiter")
    user = User.create!(email: "eng-rec-#{SecureRandom.hex(3)}@vis.test", name: "Eng Rec")
    @scoped = Membership.create!(user: user, role: recruiter_role, status: "active")
    MembershipScope.create!(
      membership: @scoped,
      dimension: dept,
      dimension_value: @eng,
      include_descendants: true
    )

    @public_eng = Person.create!(display_name: "Eng Person", visibility: "public")
    EntityDimensionValue.create!(
      entity_type: "Person", entity_id: @public_eng.id,
      dimension_id: dept.id, dimension_value_id: @eng.id
    )

    @public_sales = Person.create!(display_name: "Sales Person", visibility: "public")
    EntityDimensionValue.create!(
      entity_type: "Person", entity_id: @public_sales.id,
      dimension_id: dept.id, dimension_value_id: @sales.id
    )

    @restricted = Person.create!(display_name: "Restricted", visibility: "restricted")
  end

  teardown { Current.reset }

  test "org-wide owner sees public and restricted" do
    assert PersonVisibility.visible?(@public_eng, viewer: @owner)
    assert PersonVisibility.visible?(@restricted, viewer: @owner)
  end

  test "scoped recruiter only sees people in scope" do
    assert PersonVisibility.visible?(@public_eng, viewer: @scoped)
    refute PersonVisibility.visible?(@public_sales, viewer: @scoped)
    refute PersonVisibility.visible?(@restricted, viewer: @scoped)
  end

  test "scope_for excludes out-of-scope people" do
    ids = PersonVisibility.scope_for(@scoped).pluck(:id)
    assert_includes ids, @public_eng.id
    refute_includes ids, @public_sales.id
    refute_includes ids, @restricted.id
  end

  test "an interviewer can open the candidate they are booked to interview" do
    template = PipelineTemplate.create!(key: "vis", name: "Vis", object_type: "job")
    template.publish!(stages: [ { "key" => "onsite", "name" => "Onsite", "type" => "interview" } ])
    job = Job.create!(title: "Sales", status: "active", pipeline: Pipeline.build_from_template!(template: template))
    application = ApplicationCreator.call(job: job, person: @public_sales)
    restricted = ApplicationCreator.call(job: job, person: @restricted)
    interview = Interview.create!(application: application, stage_key: "onsite", interview_key: "chat",
                                  status: "scheduled", interviewer_user_ids: [ @scoped.user_id ])
    Interview.create!(application: restricted, stage_key: "onsite", interview_key: "chat",
                      status: "cancelled", interviewer_user_ids: [ @scoped.user_id ])

    assert PersonVisibility.visible?(@public_sales, viewer: @scoped)
    assert_includes PersonVisibility.interviewing_application_ids(@scoped).pluck(:application_id), application.id
    refute_includes PersonVisibility.scope_for(@scoped).pluck(:id), @public_sales.id, "lists and search stay in scope"
    assert_includes PersonVisibility.scope_for(@scoped).pluck(:id), @public_eng.id
    refute PersonVisibility.visible?(@restricted, viewer: @scoped), "a cancelled interview grants nothing"

    interview.update!(status: "cancelled")
    refute PersonVisibility.visible?(@public_sales, viewer: @scoped)
    assert_empty PersonVisibility.interviewing_application_ids(@scoped).pluck(:application_id)
  end
end
