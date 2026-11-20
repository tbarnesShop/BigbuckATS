# frozen_string_literal: true

require "test_helper"

class V1::CatchupLeftoversTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "Catchup", slug: "catch-#{SecureRandom.hex(3)}",
      owner_email: "owner-#{SecureRandom.hex(2)}@catch.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    GoogleSignIn.verify_domain!(domain: "catch.test")

    template = PipelineTemplate.create!(key: "catch", name: "Catch", object_type: "job")
    template.publish!(stages: [
      { "key" => "applied", "name" => "Applied", "type" => "apply" },
      { "key" => "onsite", "name" => "Onsite", "type" => "interview" }
    ])
    @pipeline = Pipeline.build_from_template!(template: template)
    @job = Job.create!(title: "Backend", status: "active", pipeline: @pipeline, openings: 2)
    @other = Job.create!(title: "Other", status: "active", pipeline: @pipeline, openings: 1)
    @person = Person.create!(display_name: "Pat Example", primary_email: "pat@example.com", owner_user_id: @user.id)
    @stranger = Person.create!(display_name: "Stranger", primary_email: "stranger@example.com")
    @mine = ApplicationCreator.call(job: @job, person: @person)
    @theirs = ApplicationCreator.call(job: @other, person: @stranger)
    team = HiringTeam.create!(job: @job)
    HiringTeamMember.create!(hiring_team: team, user: @user, team_role: "recruiter")
  end

  teardown { Current.reset }

  def headers
    { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id, "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }
  end

  test "applications page and put the caller's jobs first" do
    get "/v1/applications", params: { sort: "mine", page: 1, per_page: 1 }, headers: headers
    assert_response :success
    body = response.parsed_body
    assert_equal 2, body.dig("meta", "total")
    assert_equal 1, body.dig("meta", "page")
    assert_equal 1, body.dig("meta", "per_page")
    assert_equal [ @mine.id ], body["data"].map { |row| row["id"] }

    get "/v1/applications", params: { sort: "mine", page: 2, per_page: 1 }, headers: headers
    assert_equal [ @theirs.id ], response.parsed_body["data"].map { |row| row["id"] }
  end

  test "company show reports industry, size, and current versus former" do
    company = Company.create!(name: "Northwind", domain: "northwind.example", industry: "Biotech", employee_band: "51-200")
    PersonAffiliation.create!(person: @person, company: company, title: "Engineer", current: true)
    PersonAffiliation.create!(person: @stranger, company: company, title: "Intern", current: false)

    get "/v1/companies/#{company.id}", headers: headers
    assert_response :success
    body = response.parsed_body
    assert_equal "Biotech", body["industry"]
    assert_equal "51-200", body["employee_band"]
    assert_equal 1, body["current_count"]
    assert_equal 1, body["former_count"]
    assert_equal 2, body["affiliation_count"]
  end

  test "demo memberships lists existing members and does not mint one" do
    get "/v1/sessions/demo_memberships", params: { slug: @org.slug }
    assert_response :forbidden
    assert_equal "demo_tenant_required", response.parsed_body["code"]
    DemoSandbox.create!(surface: "tools", organization_id: @org.id, generation: 1, state: "ready",
      seeded_at: Time.current, resets_at: 1.hour.from_now)
    assert_no_difference -> { Membership.count } do
      get "/v1/sessions/demo_memberships", params: { slug: @org.slug }
    end
    assert_response :success
    emails = response.parsed_body["data"].map { |row| row["email"] }
    assert_includes emails, @user.email
    assert_equal [ "Owner" ], response.parsed_body["data"].map { |row| row["role_name"] }.uniq
  end

  test "job openings update" do
    patch "/v1/jobs/#{@job.id}", params: { job: { openings: 4 } }, headers: headers
    assert_response :success
    assert_equal 4, response.parsed_body["openings"]
    assert_equal 4, @job.reload.openings
  end

  test "person conversation lists messages" do
    Communication.create!(
      person: @person, direction: "outbound", channel: "email", subject: "Hello", body: "Next step",
      status: "sent", message_type: "outreach"
    )
    get "/v1/people/#{@person.id}/communications", headers: headers
    assert_response :success
    assert_equal [ "Hello" ], response.parsed_body["data"].map { |row| row["subject"] }
  end

  test "people search can limit to a pool" do
    project = Project.create!(name: "Warm", pipeline: @pipeline)
    ProjectMember.create!(project: project, person: @person, pipeline: @pipeline, current_stage_key: "applied", status: "active")

    get "/v1/people", params: { project_id: project.id }, headers: headers
    assert_response :success
    assert_equal [ @person.id ], response.parsed_body["data"].map { |row| row["id"] }
    assert_equal @user.email, response.parsed_body["data"].first.dig("owner", "email")
  end

  test "public careers includes culture blocks and the demo flag" do
    get "/v1/public/careers/#{@org.slug}"
    assert_response :success
    careers = response.parsed_body["careers"]
    assert_equal true, careers["demo"]
    assert_equal "How we work", careers["culture"].first["title"]
  end
end
