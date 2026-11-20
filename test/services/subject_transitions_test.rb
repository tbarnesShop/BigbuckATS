# frozen_string_literal: true

require "test_helper"

class SubjectTransitionsTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "PipeCo", slug: "pipe-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@p.test", owner_name: "O"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id

    @template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    @template.publish!(stages: [
      { "key" => "review", "name" => "Review", "type" => "review" },
      { "key" => "onsite", "name" => "Onsite", "type" => "interview" },
      { "key" => "offer", "name" => "Offer", "type" => "offer" }
    ])
    @pipeline = Pipeline.build_from_template!(template: @template)
    @job = Job.create!(title: "Engineer", status: "active", pipeline: @pipeline)
    @person = Person.create!(display_name: "Cand")
  end

  teardown { Current.reset }

  test "one transition path serves applications and project members" do
    application = ApplicationCreator.call(job: @job, person: @person)
    SubjectTransitions.move(subject: application, to_stage_key: "onsite")
    assert_equal "onsite", application.reload.current_stage_key
    assert_equal 1, application.stage_transitions.where(command: "move").count

    project_template = PipelineTemplate.create!(key: "sourcing", name: "Sourcing", object_type: "project")
    project_template.publish!(stages: [
      { "key" => "prospect", "name" => "Prospect", "type" => "review" },
      { "key" => "reached-out", "name" => "Reached out", "type" => "screen" }
    ])
    project_pipeline = Pipeline.build_from_template!(template: project_template, scope: "project")
    project = Project.create!(name: "Pool", pipeline: project_pipeline, job: @job)
    member = ProjectMember.create!(
      project: project, person: @person, pipeline: project_pipeline,
      pipeline_version: project_pipeline.version, current_stage_key: "prospect"
    )
    SubjectTransitions.move(subject: member, to_stage_key: "reached-out")
    assert_equal "reached-out", member.reload.current_stage_key
    assert_equal 1, member.stage_transitions.where(command: "move").count
  end

  test "conversion links project member to application" do
    project = Project.create!(name: "Pool", job: @job)
    member = ProjectMember.create!(project: project, person: @person, status: "active")
    application = ProjectConversion.call(member: member)
    assert_equal application.id, member.reload.converted_application_id
    assert_equal member.id, application.source_project_member_id
    assert_equal "converted", member.status
  end
end
