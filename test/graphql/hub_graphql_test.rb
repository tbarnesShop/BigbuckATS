# frozen_string_literal: true

require "test_helper"

class HubGraphqlTest < ActionDispatch::IntegrationTest
  setup do
    @header_auth_was = Rails.configuration.x.header_auth
    Rails.configuration.x.header_auth = false
    @provisioned = OrganizationProvisioner.call(
      name: "Hub Graph", slug: "hg-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@hg.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @owner = @provisioned[:user]
    within_org do
      GoogleSignIn.verify_domain!(domain: "hg.test")
      @template = PipelineTemplate.create!(key: "hub", name: "Hub", object_type: "job")
      @template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
      @job = Job.create!(title: "Backend", status: "active", pipeline: Pipeline.build_from_template!(template: @template))
      @person = Person.create!(display_name: "Ada", primary_email: "ada@example.com")
      @application = ApplicationCreator.call(job: @job, person: @person)
      @token = CredentialIssuer.call(kind: "personal", name: "owner", user: @owner, scopes: Scopes::ALL, audit: false).token
      @scheduler = CredentialIssuer.call(kind: "personal", name: "sched", user: @owner, scopes: %w[scheduling:write], audit: false).token
    end
  end

  teardown do
    Rails.configuration.x.header_auth = @header_auth_was
    Current.reset
  end

  test "today, interviews and offers match the hub lists" do
    within_org do
      Interview.create!(
        application: @application, stage_key: "applied", interview_key: "screen", status: "completed",
        starts_at: 2.hours.ago, ends_at: 1.hour.ago, interviewer_user_ids: [ @owner.id ]
      )
      Interview.create!(
        application: @application, stage_key: "applied", interview_key: "hm", status: "scheduled",
        starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour, interviewer_user_ids: [ @owner.id ]
      )
      Offer.create!(application: @application, status: "draft", version: 1)
    end

    data = gql(<<~GQL)
      {
        today { reviews { id person { displayName } } feedback { id application { job { title } } } jobs { openings activeCount } }
        interviews(tab: "upcoming") { id }
        offers { counts { status count } nodes { id status } }
      }
    GQL
    assert_equal @application.id, data.dig("data", "today", "reviews", 0, "id")
    assert_equal "Ada", data.dig("data", "today", "reviews", 0, "person", "displayName")
    assert_equal "Backend", data.dig("data", "today", "feedback", 0, "application", "job", "title")
    assert_equal 1, data.dig("data", "interviews").size
    draft = data.dig("data", "offers", "counts").find { |row| row["status"] == "draft" }
    assert_equal 1, draft["count"]
    assert_equal "draft", data.dig("data", "offers", "nodes", 0, "status")

    bad = gql("{ interviews(tab: \"nope\") { id } }")
    assert_equal "invalid_interview", bad.dig("errors", 0, "extensions", "code")
  end

  test "interviews scope mine adds hiring-team jobs to my own panels" do
    ids = within_org do
      other_job = Job.create!(title: "Frontend", status: "active", pipeline: Pipeline.build_from_template!(template: @template))
      other_app = ApplicationCreator.call(job: other_job, person: Person.create!(display_name: "Bo", primary_email: "bo@example.com"))
      team = HiringTeam.create!(job: @job)
      HiringTeamMember.create!(hiring_team: team, user: @owner, team_role: "recruiter")
      soon = 1.day.from_now
      book = lambda do |application, panel|
        Interview.create!(application: application, stage_key: "applied", interview_key: "screen", status: "scheduled",
          starts_at: soon, ends_at: soon + 30.minutes, interviewer_user_ids: panel).id
      end
      {
        on_panel: book.call(other_app, [ @owner.id ]),
        team_job: book.call(@application, [ "someone-else" ]),
        neither: book.call(other_app, [ "someone-else" ])
      }
    end

    mine = gql('{ interviews(tab: "upcoming", scope: "mine") { id } }').dig("data", "interviews").map { |row| row["id"] }
    assert_equal ids.values_at(:on_panel, :team_job).sort, mine.sort
    all = gql('{ interviews(tab: "upcoming", scope: "all") { id } }').dig("data", "interviews").map { |row| row["id"] }
    assert_equal ids.values.sort, all.sort
    bad = gql('{ interviews(scope: "team") { id } }')
    assert_equal "invalid_interview", bad.dig("errors", 0, "extensions", "code")
  end

  test "today reviews omit restricted people and confidential jobs without nulling the board" do
    within_org do
      hidden_person = Person.create!(display_name: "Restricted sample", visibility: "restricted")
      ApplicationCreator.call(job: @job, person: hidden_person)
      hidden_job = Job.create!(title: "Confidential sample", code_name: "Quiet team", status: "active", confidential: true, pipeline: @job.pipeline)
      ApplicationCreator.call(job: hidden_job, person: @person)
      @public_token = CredentialIssuer.call(kind: "personal", name: "public reads", user: @owner,
        scopes: %w[people:read jobs:read], audit: false).token
    end
    data = gql("{ today { reviews { id person { displayName } } jobs { title } } }", token: @public_token)
    assert_nil data["errors"], data.inspect
    assert_equal [ @application.id ], data.dig("data", "today", "reviews").map { |row| row["id"] }
    assert_equal [ "Backend" ], data.dig("data", "today", "jobs").map { |row| row["title"] }
  end

  test "calendar connect, rubrics, templates and the application form" do
    refused = gql(<<~GQL, token: @scheduler)
      mutation { connectCalendar(input: { calendarId: "ada@hg.test", kind: "domain" }) { calendar { id } userErrors { code } } }
    GQL
    assert_equal "insufficient_permission", refused.dig("data", "connectCalendar", "userErrors", 0, "code")

    pending = gql(<<~GQL)
      mutation { connectCalendar(input: { calendarId: "ada@hg.test", secretRef: "sm://demo" }) {
        calendar { status calendarId } userErrors { code }
      } }
    GQL
    assert_equal "pending", pending.dig("data", "connectCalendar", "calendar", "status")
    refute pending.dig("data", "connectCalendar", "calendar").key?("secretRef")

    rubric = gql(<<~GQL)
      mutation { createScorecardRubric(input: { key: "screen", name: "Screen", attributes: [{ key: "communication", label: "Communication" }] }) {
        rubric { key attributesSpec } userErrors { code message }
      } }
    GQL
    assert_equal "screen", rubric.dig("data", "createScorecardRubric", "rubric", "key")

    field = gql(<<~GQL)
      mutation { createCustomField(input: { entity: "application", key: "roast", label: "Roast", fieldType: "text", showOnApply: true }) {
        field { id showOnApply } userErrors { code message }
      } }
    GQL
    assert_equal true, field.dig("data", "createCustomField", "field", "showOnApply"), field.inspect
    field_id = field.dig("data", "createCustomField", "field", "id")

    form = gql(<<~GQL)
      mutation { updateApplicationForm(input: { requiredFields: ["display_name", "email", "phone"], screeningFieldIds: ["#{field_id}"] }) {
        applicationForm { requiredFields screeningQuestions { key } } userErrors { code message }
      } }
    GQL
    assert_includes form.dig("data", "updateApplicationForm", "applicationForm", "requiredFields"), "phone"
    assert_equal [ "roast" ], form.dig("data", "updateApplicationForm", "applicationForm", "screeningQuestions").map { |row| row["key"] }

    template = gql(<<~GQL)
      mutation { createMessageTemplate(input: { key: "welcome", messageType: "outreach", subject: "Hi", body: "Hello" }) {
        template { key locale } userErrors { code }
      } }
    GQL
    assert_equal "en", template.dig("data", "createMessageTemplate", "template", "locale")
    listed = gql("{ messageTemplates { key } }")
    assert_includes listed.dig("data", "messageTemplates").map { |row| row["key"] }, "welcome" # new orgs also start with starter templates
  end

  test "registered job workspace stays within complexity limits and paginates candidates" do
    within_org do
      22.times do |index|
        person = Person.create!(display_name: "Candidate #{index}")
        ApplicationCreator.call(job: @job, person: person)
      end
    end
    documents = JSON.parse(File.read(PersistedQueries::PATH))
    id, = documents.find { |_id, document| document.include?("query JobWorkspace(") }
    assert id, "JobWorkspace must be registered"
    token = within_org { CredentialIssuer.call(kind: "session", name: "browser", user: @owner, expires_at: 1.hour.from_now, audit: false).token }
    PersistedQueries.reload!
    post "/graphql", params: { id: id, variables: { id: @job.id } }, headers: { "Authorization" => "Bearer #{token}" }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_nil body["errors"], body.inspect
    first = body.dig("data", "job", "applications")
    assert_equal 20, first["nodes"].length
    assert first.dig("pageInfo", "hasNextPage")
    post "/graphql", params: { id: id, variables: { id: @job.id, after: first.dig("pageInfo", "endCursor") } }, headers: { "Authorization" => "Bearer #{token}" }, as: :json
    assert_response :success
    last = response.parsed_body.dig("data", "job", "applications")
    assert_equal 3, last["nodes"].length
    refute last.dig("pageInfo", "hasNextPage")
    assert_empty first["nodes"].map { |node| node["id"] } & last["nodes"].map { |node| node["id"] }
  end

  private

  def within_org
    Current.organization_id = @org.id
    Current.actor_id = @owner.id
    yield
  ensure
    Current.reset
  end

  def gql(query, token: @token)
    post "/graphql", params: { query: query }, headers: { "Authorization" => "Bearer #{token}" }, as: :json
    assert_response :success
    JSON.parse(response.body)
  end
end
