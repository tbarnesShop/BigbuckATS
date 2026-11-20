# frozen_string_literal: true

require "test_helper"

class V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "PoolCo", slug: "pool-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@pool.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    job_template = PipelineTemplate.create!(key: "job", name: "Job", object_type: "job")
    job_template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    @job = Job.create!(
      title: "Platform Eng",
      status: "active",
      pipeline: Pipeline.build_from_template!(template: job_template)
    )
    @person = Person.create!(display_name: "Sam Sourced", primary_email: "sam@pool.test", lifecycle_stage: "prospect")
  end

  teardown { Current.reset }

  def headers
    {
      "X-Organization-Id" => @org.id,
      "X-Actor-Id" => @user.id,
      "Idempotency-Key" => "k-#{SecureRandom.hex(4)}"
    }
  end

  test "create project, add member, move stage, convert to application" do
    post "/v1/projects",
         params: { project: { name: "Platform warm bench", job_id: @job.id } },
         headers: headers, as: :json
    assert_response :created
    project_id = response.parsed_body["id"]
    assert_equal 4, response.parsed_body.dig("pipeline", "stages").size

    post "/v1/projects/#{project_id}/members",
         params: { member: { person_id: @person.id } },
         headers: headers, as: :json
    assert_response :created
    member_id = response.parsed_body["id"]
    assert_equal "prospect", response.parsed_body["current_stage_key"]
    assert_equal "Sam Sourced", response.parsed_body.dig("person", "display_name")

    post "/v1/project_members/#{member_id}/transitions",
         params: { to_stage_key: "reached-out", reason: "first touch" },
         headers: headers, as: :json
    assert_response :created
    assert_equal "reached-out", response.parsed_body["current_stage_key"]

    post "/v1/project_members/#{member_id}/convert",
         params: { job_id: @job.id },
         headers: headers, as: :json
    assert_response :created
    assert_equal "converted", response.parsed_body.dig("member", "status")
    assert response.parsed_body.dig("application", "id").present?
    assert_equal @job.id, response.parsed_body.dig("application", "job_id")

    get "/v1/projects/#{project_id}/members",
        headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :success
    assert_equal 1, response.parsed_body["data"].size
  end
end
