# frozen_string_literal: true

require "test_helper"

# M6a proving test: an offer routes to the department head by policy.
class OfferRoutingTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "OfferCo", slug: "of-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@of.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id

    @dept_head = User.create!(email: "head-#{SecureRandom.hex(2)}@of.test", name: "Dept Head")
    @hm = User.create!(email: "hm-#{SecureRandom.hex(2)}@of.test", name: "HM")
    @recruiter = @provisioned[:user]

    department = @provisioned[:dimensions][:department]
    @engineering = DimensionValue.create!(
      dimension: department, key: "engineering", label: "Engineering",
      attributes_json: { "head" => @dept_head.id }
    )

    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [
      { "key" => "offer", "name" => "Offer", "type" => "offer" }
    ])
    pipeline = Pipeline.build_from_template!(template: template)
    @job = Job.create!(title: "Staff Eng", status: "active", pipeline: pipeline)
    EntityDimensionValue.create!(
      entity_type: "Job", entity_id: @job.id,
      dimension: department, dimension_value: @engineering
    )
    team = HiringTeam.create!(job: @job)
    HiringTeamMember.create!(hiring_team: team, user: @hm, team_role: "hiring-manager")

    # Higher-priority engineering policy routes to department head
    @eng_policy = ApprovalPolicy.create!(
      key: "engineering-offers", name: "Engineering offers",
      applies_to: "offer", priority: 10, is_catch_all: false,
      conditions: { "job.dimensions.department" => "engineering" },
      reapproval_fields: %w[base-salary]
    )
    ApprovalPolicyStep.create!(
      approval_policy: @eng_policy, position: 1, name: "Department head",
      mode: "sequential",
      approvers: [ "attribute:job.dimensions.department.head" ],
      require_mode: "all", if_no_approver: "block"
    )

    # Catch-all required
    @default = ApprovalPolicy.create!(
      key: "default-offers", name: "Default",
      applies_to: "offer", priority: 0, is_catch_all: true, conditions: nil
    )
    ApprovalPolicyStep.create!(
      approval_policy: @default, position: 1, name: "Hiring manager",
      mode: "sequential",
      approvers: [ "role:hiring-manager" ],
      require_mode: "all", if_no_approver: "skip"
    )

    person = Person.create!(display_name: "Cand", primary_email: "c@of.test")
    @application = ApplicationCreator.call(job: @job, person: person)
  end

  teardown { Current.reset }

  test "offer routes to the department head by policy" do
    offer = OfferSubmitter.create_draft!(
      application: @application,
      fields: { "base-salary" => 185_000, "start-date" => "2026-12-01" }
    )
    OfferSubmitter.submit!(offer: offer)

    offer.reload
    assert_equal "pending_approval", offer.status
    assert_equal @eng_policy.id, offer.current_version.approval_policy_id

    approvals = Approval.where(entity_id: offer.id, status: "pending")
    assert_equal 1, approvals.count
    assert_equal @dept_head.id, approvals.first.approver_user_id
    assert_equal "attribute:job.dimensions.department.head", approvals.first.resolved_from

    OfferApprover.approve!(approval: approvals.first, actor_id: @dept_head.id)
    assert_equal "approved", offer.reload.status
  end

  test "non-matching job falls through to catch-all hiring manager" do
    other = DimensionValue.create!(
      dimension: @provisioned[:dimensions][:department],
      key: "sales", label: "Sales",
      attributes_json: { "head" => @dept_head.id }
    )
    template = PipelineTemplate.create!(key: "sales", name: "Sales", object_type: "job")
    template.publish!(stages: [ { "key" => "offer", "name" => "Offer", "type" => "offer" } ])
    pipeline = Pipeline.build_from_template!(template: template)
    job = Job.create!(title: "AE", status: "active", pipeline: pipeline)
    EntityDimensionValue.create!(
      entity_type: "Job", entity_id: job.id,
      dimension: @provisioned[:dimensions][:department], dimension_value: other
    )
    team = HiringTeam.create!(job: job)
    HiringTeamMember.create!(hiring_team: team, user: @hm, team_role: "hiring-manager")
    person = Person.create!(display_name: "S", primary_email: "s@of.test")
    application = ApplicationCreator.call(job: job, person: person)

    offer = OfferSubmitter.create_draft!(application: application, fields: { "base-salary" => 90_000 })
    OfferSubmitter.submit!(offer: offer)

    assert_equal @default.id, offer.reload.current_version.approval_policy_id
    approvals = Approval.where(entity_id: offer.id, status: "pending")
    assert_equal 1, approvals.count
    assert_equal @hm.id, approvals.first.approver_user_id
  end

  test "a job with no hiring manager routes the offer to the workspace owner, not straight to approved" do
    @default.steps.first.update!(if_no_approver: "fallback", fallback_approver: "org-role:owner")
    application = application_on_job_without_hiring_manager

    offer = OfferSubmitter.create_draft!(application: application, fields: { "base-salary" => 90_000 })
    OfferSubmitter.submit!(offer: offer)

    assert_equal "pending_approval", offer.reload.status
    approvals = Approval.where(entity_id: offer.id, status: "pending")
    assert_equal [ @provisioned[:user].id ], approvals.map(&:approver_user_id)
    assert_equal "org-role:owner", approvals.first.resolved_from
  end

  test "a fallback that finds no one blocks the submit instead of leaving an offer no one can approve" do
    @default.steps.first.update!(if_no_approver: "fallback", fallback_approver: "org-role:nobody")
    application = application_on_job_without_hiring_manager
    offer = OfferSubmitter.create_draft!(application: application, fields: { "base-salary" => 90_000 })

    error = assert_raises(ArgumentError) { OfferSubmitter.submit!(offer: offer) }
    assert_equal "no_approver_block", error.message
    assert_equal "draft", offer.reload.status
  end

  test "rescind clears live slot and cancels pending approvals" do
    offer = OfferSubmitter.create_draft!(application: @application, fields: { "base-salary" => 1 })
    OfferSubmitter.submit!(offer: offer)
    OfferRescinder.call(offer: offer, reason_key: "role_filled")
    assert_equal "rescinded", offer.reload.status
    assert_nil offer.live_key
    assert_equal 0, Approval.where(entity_id: offer.id, status: "pending").count
  end

  private

  def application_on_job_without_hiring_manager
    template = PipelineTemplate.create!(key: "ops-#{SecureRandom.hex(2)}", name: "Ops", object_type: "job")
    template.publish!(stages: [ { "key" => "offer", "name" => "Offer", "type" => "offer" } ])
    job = Job.create!(title: "Ops", status: "active", pipeline: Pipeline.build_from_template!(template: template))
    HiringTeam.create!(job: job).members.create!(user: @recruiter, team_role: "recruiter")
    person = Person.create!(display_name: "N", primary_email: "n-#{SecureRandom.hex(2)}@of.test")
    ApplicationCreator.call(job: job, person: person)
  end
end
