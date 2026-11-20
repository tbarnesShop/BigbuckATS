# frozen_string_literal: true

require "test_helper"

class V1::EnrollmentPlanTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "PlanCo", slug: "pl-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@pl.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    @viewer = @provisioned[:membership]
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@pl.test", provider: "sandbox",
      status: "connected", secret_ref: "sandbox://mailbox", user: @user)
    @sequence = Sequence.find_by!(key: "starter-outreach")
    @good = person("Good Gina", "gina@pl.test")
    @dnc = person("Dnc Dan", "dan@pl.test").tap { |p| p.update!(do_not_contact: true) }
    @opted = person("Opted Olly", "olly@pl.test").tap { |p| OptOut.add!(person: p, source: "unsubscribe_link") }
    @active = person("Active Abe", "abe@pl.test")
    SequenceEnrollment.create!(sequence: @sequence, person: @active, mailbox: @mailbox, step_index: 1, status: "active")
    @cool = person("Cool Cat", "cat@pl.test")
    Communication.create!(person: @cool, direction: "outbound", channel: "email", status: "sent",
      subject: "hi", body: "hi", message_type: "outreach")
    @bad_co = person("Corp Cy", "cy@blocked-corp.test")
    DncCompany.create!(domain: "blocked-corp.test")
    @noemail = Person.create!(display_name: "No Email Nia", lifecycle_stage: "prospect")
  end

  teardown { Current.reset }

  def person(name, email)
    PersonMatcher.find_or_create(display_name: name, email: email, viewer: @viewer).person
  end

  def headers
    { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id, "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }
  end

  def ids = [ @good, @dnc, @opted, @active, @cool, @bad_co, @noemail ].map(&:id)

  test "dry run reports each skip reason and writes nothing" do
    assert_no_difference -> { SequenceEnrollment.count } do
      post "/v1/sequences/#{@sequence.id}/enrollment_plan", params: { person_ids: ids }, headers: headers, as: :json
    end
    assert_response :success
    body = response.parsed_body
    reasons = body["skipped"].to_h { |s| [ s["display_name"], s["reason"] ] }
    assert_equal "do_not_contact", reasons["Dnc Dan"]
    # Opting out also marks the person do-not-contact, which is checked first.
    assert_includes %w[do_not_contact opted_out], reasons["Opted Olly"]
    assert_equal "active_enrollment", reasons["Active Abe"]
    assert_equal "company_dnc", reasons["Corp Cy"]
    assert_equal "no_email", reasons["No Email Nia"]
    assert_equal "cooldown", reasons["Cool Cat"]
    assert_equal [ "Good Gina" ], body["will_enroll"].map { |p| p["display_name"] }
    assert_equal 7, body["counts"]["total"]
  end

  test "exclusions are honoured and commit enrolls only eligible people" do
    post "/v1/sequences/#{@sequence.id}/enroll_planned", params: { person_ids: ids, exclude_person_ids: [ @cool.id ] }, headers: headers, as: :json
    assert_response :success
    assert_equal 1, response.parsed_body["enrolled"]
    assert SequenceEnrollment.exists?(person_id: @good.id, status: "active")
    assert_not SequenceEnrollment.exists?(person_id: @dnc.id)
  end

  test "selection by pool" do
    pipeline = Pipeline.build_from_template!(template: PipelineTemplate.create!(key: "p", name: "P", object_type: "project").tap { |t|
      t.publish!(stages: [ { "key" => "prospect", "name" => "Prospect", "type" => "source" } ])
    }, scope: "project")
    project = Project.create!(name: "Bench", pipeline: pipeline)
    ProjectMember.create!(project: project, person: @good, pipeline: pipeline, pipeline_version: pipeline.version, current_stage_key: "prospect", status: "active", version: 1)
    post "/v1/sequences/#{@sequence.id}/enrollment_plan", params: { project_id: project.id }, headers: headers, as: :json
    assert_response :success
    assert_equal 1, response.parsed_body["counts"]["will_enroll"]
  end

  test "a selection is required" do
    post "/v1/sequences/#{@sequence.id}/enrollment_plan", params: {}, headers: headers, as: :json
    assert_response :unprocessable_entity
  end
end
