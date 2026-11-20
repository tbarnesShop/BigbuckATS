# frozen_string_literal: true

require "test_helper"

class V1::PoolsV2Test < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "PoolV2", slug: "pv2-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@pv2.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    viewer = @provisioned[:membership]
    @ana = PersonMatcher.find_or_create(display_name: "Ana Go", email: "ana@pv2.test", viewer: viewer).person
    @ben = PersonMatcher.find_or_create(display_name: "Ben Go", email: "ben@pv2.test", viewer: viewer).person
    @cy = PersonMatcher.find_or_create(display_name: "Cy Ruby", email: "cy@pv2.test", viewer: viewer).person
    @ana.update!(headline: "Go engineer", city: "Philadelphia")
    @ben.update!(headline: "Go engineer", city: "Philadelphia")
    @cy.update!(headline: "Ruby engineer", city: "Boston")
    template = PipelineTemplate.create!(key: "job", name: "Job", object_type: "job")
    template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    @job = Job.create!(title: "Closed role", status: "closed", pipeline: Pipeline.build_from_template!(template: template))
  end

  teardown { Current.reset }

  def headers
    { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id, "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }
  end

  def create_pool(extra = {})
    post "/v1/projects", params: { project: { name: "Go bench", description: "Go folks" }.merge(extra) }, headers: headers, as: :json
    assert_response :created
    response.parsed_body
  end

  test "pool has an owner defaulting to the creator, a description and can be updated" do
    pool = create_pool
    assert_equal @user.id, pool["owner_user_id"]
    assert_equal "Go folks", pool["description"]
    patch "/v1/projects/#{pool['id']}", params: { project: { description: "Updated" } }, headers: headers, as: :json
    assert_response :success
    assert_equal "Updated", response.parsed_body["description"]
  end

  test "bulk add by ids is idempotent per person" do
    pool = create_pool
    post "/v1/projects/#{pool['id']}/people", params: { person_ids: [ @ana.id, @ben.id ] }, headers: headers, as: :json
    assert_response :created
    assert_equal 2, response.parsed_body["added"]
    post "/v1/projects/#{pool['id']}/people", params: { person_ids: [ @ana.id, @cy.id ] }, headers: headers, as: :json
    assert_equal 1, response.parsed_body["added"]
    assert_equal 1, response.parsed_body["already_members"]
    assert_equal 3, response.parsed_body["member_count"]
  end

  test "smart pool refreshes from its saved search" do
    search = SavedSearch.create!(user_id: @user.id, name: "Go in Philly", filters: { "q" => "go", "location" => "Philadelphia" })
    pool = create_pool(saved_search_id: search.id)
    post "/v1/projects/#{pool['id']}/people", params: {}, headers: headers, as: :json
    assert_response :created
    assert_equal 2, response.parsed_body["added"]
    @cy.update!(headline: "Go engineer", city: "Philadelphia")
    post "/v1/projects/#{pool['id']}/people", params: {}, headers: headers, as: :json
    assert_equal 1, response.parsed_body["added"]
  end

  test "ad-hoc filters add matching people" do
    pool = create_pool
    post "/v1/projects/#{pool['id']}/people", params: { filters: { q: "ruby" } }, headers: headers, as: :json
    assert_response :created
    assert_equal 1, response.parsed_body["added"]
  end

  test "closed job's rejected applicants can be pulled into a pool" do
    [ [ @ana, "rejected" ], [ @ben, "active" ], [ @cy, "withdrawn" ] ].each do |person, status|
      Application.create!(person: person, job: @job, pipeline: @job.pipeline, pipeline_version: @job.pipeline.version,
        current_stage_key: "applied", status: status)
    end
    pool = create_pool
    post "/v1/projects/#{pool['id']}/from_job", params: { job_id: @job.id }, headers: headers, as: :json
    assert_response :created
    assert_equal 2, response.parsed_body["added"]
  end

  test "bulk move and per-member note" do
    pool = create_pool
    post "/v1/projects/#{pool['id']}/people", params: { person_ids: [ @ana.id, @ben.id ] }, headers: headers, as: :json
    post "/v1/projects/#{pool['id']}/transitions", params: { person_ids: [ @ana.id, @ben.id ], to_stage_key: "reached-out" }, headers: headers, as: :json
    assert_response :success
    assert_equal 2, response.parsed_body["moved"]
    member = ProjectMember.find_by(person_id: @ana.id)
    assert_equal "reached-out", member.current_stage_key
    patch "/v1/project_members/#{member.id}", params: { member: { note: "Warm intro via Dana" } }, headers: headers, as: :json
    assert_response :success
    assert_equal "Warm intro via Dana", response.parsed_body["note"]
  end
end
