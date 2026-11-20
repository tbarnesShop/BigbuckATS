# frozen_string_literal: true

require "test_helper"

# M6b proving test: routed offer is accepted and hires.
class OfferAcceptanceFlowTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "HireCo", slug: "hi-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@hi.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id
    @org = @provisioned[:organization]
    @org.update!(settings: { "offers_hire_on_accept" => true, "hire_requires_accepted_offer" => true })

    @dept_head = User.create!(email: "head-#{SecureRandom.hex(2)}@hi.test", name: "Head")
    department = @provisioned[:dimensions][:department]
    engineering = DimensionValue.create!(
      dimension: department, key: "engineering", label: "Engineering",
      attributes_json: { "head" => @dept_head.id }
    )

    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [ { "key" => "offer", "name" => "Offer", "type" => "offer" } ])
    pipeline = Pipeline.build_from_template!(template: template)
    @job = Job.create!(title: "Staff Eng", status: "active", pipeline: pipeline)
    EntityDimensionValue.create!(
      entity_type: "Job", entity_id: @job.id,
      dimension: department, dimension_value: engineering
    )

    policy = ApprovalPolicy.create!(
      key: "eng-offers", name: "Eng", applies_to: "offer", priority: 10,
      conditions: { "job.dimensions.department" => "engineering" }
    )
    ApprovalPolicyStep.create!(
      approval_policy: policy, position: 1, name: "Dept head",
      approvers: [ "attribute:job.dimensions.department.head" ], require_mode: "all"
    )
    ApprovalPolicy.create!(
      key: "default-offers", name: "Default", applies_to: "offer",
      priority: 0, is_catch_all: true
    )

    @letter_template = OfferTemplate.create!(
      key: "us-ft", name: "US FT",
      body: "Dear {{ candidate.display_name }}, offer for {{ job.title }} at {{ offer.fields.base-salary }}.",
      expires_after_days: 7
    )

    @person = Person.create!(display_name: "Alex Candidate", primary_email: "alex@hi.test")
    @application = ApplicationCreator.call(job: @job, person: @person)
  end

  teardown { Current.reset }

  test "routed offer is accepted and hires" do
    offer = OfferSubmitter.create_draft!(
      application: @application,
      fields: { "base-salary" => 190_000, "start-date" => "2027-01-05" }
    )
    OfferSubmitter.submit!(offer: offer)
    approval = Approval.find_by!(entity_id: offer.id, status: "pending")
    assert_equal @dept_head.id, approval.approver_user_id
    OfferApprover.approve!(approval: approval, actor_id: @dept_head.id)
    assert_equal "approved", offer.reload.status

    sent = OfferSender.call(
      offer: offer,
      template: @letter_template,
      to_email: "alex@hi.test"
    )
    assert_equal "sent", offer.reload.status
    assert_includes sent.document.body_html, "Alex Candidate"
    assert_includes sent.document.body_html, "190,000"

    result = OfferAcceptance.accept!(
      token: sent.token,
      ip_address: "203.0.113.10",
      user_agent: "TestAgent/1.0",
      typed_name: "Alex Candidate"
    )
    assert result.hired
    assert_equal "accepted", offer.reload.status
    assert_equal "hired", @application.reload.status
    assert_equal "employee", @person.reload.lifecycle_stage
    assert OfferResponse.exists?(offer_version_id: offer.current_version_id, response: "accepted")

    packet = HirePacket.build(application: @application)
    assert_equal @application.id, packet["application_id"]
    assert_equal "hired", packet["status"]
    assert_equal 190_000, packet["offer"]["fields"]["base-salary"]
    assert packet["offer"]["document_sha256"].present?
  end

  test "hire without accepted offer is refused when required" do
    assert_raises(ArgumentError) { SubjectTransitions.hire(subject: @application) }
  end

  test "missing letter token refuses generation" do
    bad = OfferTemplate.create!(key: "bad", name: "Bad", body: "Hi {{ offer.fields.missing-field }}")
    offer = OfferSubmitter.create_draft!(application: @application, fields: { "base-salary" => 1 })
    # Force approved without full policy dance for this unit check
    offer.update!(status: "approved")
    assert_raises(MessageRenderer::MissingToken) do
      LetterGenerator.call(offer: offer, template: bad)
    end
  end
end
