# frozen_string_literal: true

require "test_helper"

# POST /graphql with real credentials (header harness off, as in production).
class GraphqlApiTest < ActionDispatch::IntegrationTest
  setup do
    @header_auth_was = Rails.configuration.x.header_auth
    Rails.configuration.x.header_auth = false

    @provisioned = OrganizationProvisioner.call(
      name: "Graph Co", slug: "graph-#{SecureRandom.hex(4)}",
      owner_email: "owner-#{SecureRandom.hex(4)}@graph.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @owner = @provisioned[:user]
    within_org do
      template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
      template.publish!(stages: [
        { "key" => "applied", "name" => "Applied", "type" => "apply" },
        { "key" => "screen", "name" => "Screen", "type" => "review" },
        { "key" => "offer", "name" => "Offer", "type" => "offer" }
      ])
      pipeline = Pipeline.build_from_template!(template: template)
      @job = Job.create!(title: "Platform Engineer", status: "active", pipeline: pipeline)
      @secret_job = Job.create!(title: "Stealth Role", status: "active", confidential: true, code_name: "Falcon",
                                pipeline: Pipeline.build_from_template!(template: template))
      @person = Person.create!(display_name: "Ada Lovelace", primary_email: "ada@example.com")
      @restricted = Person.create!(display_name: "Quiet Person", visibility: "restricted")
      @application = ApplicationCreator.call(job: @job, person: @person)
      @hm_user = User.create!(email: "hm-#{SecureRandom.hex(3)}@graph.test", name: "HM")
      @hm_membership = Membership.create!(user: @hm_user, role: @provisioned[:roles].fetch("hiring_manager"), status: "active")
    end
  end

  teardown do
    Rails.configuration.x.header_auth = @header_auth_was
    PersistedQueries.reload!
    Current.reset
  end

  test "an unauthenticated request is refused" do
    post "/graphql", params: { query: "{ viewer { actorType } }" }, as: :json
    assert_response :unauthorized
  end

  test "viewer reports who is calling and what they may do" do
    data = gql("{ viewer { organizationId actorType roleKey permissions user { email } agent { id } } }",
               token: personal_token(%w[people:read jobs:read]))
    viewer = data.dig("data", "viewer")
    assert_equal @org.id, viewer["organizationId"]
    assert_equal "user", viewer["actorType"]
    assert_equal "owner", viewer["roleKey"]
    assert_equal @owner.email, viewer.dig("user", "email")
    assert_includes viewer["permissions"], "person.read"
    refute_includes viewer["permissions"], "person.create", "scopes limit a personal token"
  end

  test "people respect visibility: restricted people are hidden without read_restricted" do
    hm = session_like_token(@hm_user)
    data = gql("{ people(first: 50) { nodes { displayName } } person(id: \"#{@restricted.id}\") { displayName } }", token: hm)
    names = data.dig("data", "people", "nodes").map { |n| n["displayName"] }
    refute_includes names, "Quiet Person"
    assert_nil data.dig("data", "person")

    owner = personal_token(%w[people:read_restricted])
    data = gql("{ person(id: \"#{@restricted.id}\") { displayName } }", token: owner)
    assert_equal "Quiet Person", data.dig("data", "person", "displayName")
  end

  test "a field the caller lacks permission for returns a coded error" do
    data = gql("{ jobs(first: 5) { nodes { title } } applications(first: 5) { nodes { id } } }",
               token: personal_token(%w[people:read]))
    codes = data["errors"].map { |e| e.dig("extensions", "code") }.uniq
    assert_equal [ "insufficient_permission" ], codes
  end

  test "confidential jobs are hidden without job.read_confidential" do
    token = personal_token(%w[jobs:read])
    titles = gql("{ jobs(first: 10) { nodes { title } } }", token: token).dig("data", "jobs", "nodes").map { |n| n["title"] }
    assert_includes titles, "Platform Engineer"
    refute_includes titles, "Stealth Role"
    assert_nil gql("{ job(id: \"#{@secret_job.id}\") { title } }", token: token).dig("data", "job")
  end

  test "nested reads batch through the dataloader and resolve stages" do
    data = gql(<<~GQL, token: personal_token(%w[jobs:read people:read]))
      { job(id: "#{@job.id}") { title stages { key name } applications(first: 10) { nodes { currentStageKey person { displayName } } } } }
    GQL
    job = data.dig("data", "job")
    assert_equal %w[applied screen offer hired], job["stages"].map { |s| s["key"] }, "pipelines end in the system Hired stage"
    assert_equal "Ada Lovelace", job.dig("applications", "nodes", 0, "person", "displayName")
  end

  test "moveApplicationStage refuses a stale version and moves with the current one" do
    token = personal_token(%w[applications:transition jobs:read people:read])
    mutation = <<~GQL
      mutation($id: ID!, $to: String!, $v: Int) {
        moveApplicationStage(input: { applicationId: $id, toStageKey: $to, expectedVersion: $v }) {
          application { currentStageKey version }
          userErrors { code message path }
        }
      }
    GQL

    stale = gql(mutation, token: token, variables: { id: @application.id, to: "screen", v: @application.version + 5 })
    assert_equal "stale_version", stale.dig("data", "moveApplicationStage", "userErrors", 0, "code")

    moved = gql(mutation, token: token, variables: { id: @application.id, to: "screen", v: @application.version })
    payload = moved.dig("data", "moveApplicationStage")
    assert_empty payload["userErrors"]
    assert_equal "screen", payload.dig("application", "currentStageKey")
    assert_equal @application.version + 1, payload.dig("application", "version")

    unknown = gql(mutation, token: token, variables: { id: @application.id, to: "nowhere" })
    assert_equal "invalid_transition", unknown.dig("data", "moveApplicationStage", "userErrors", 0, "code")
  end

  test "transition scope alone cannot mutate an invisible candidate" do
    token = personal_token(%w[applications:transition])
    data = gql(<<~GQL, token: token)
      mutation { rejectApplication(input: { applicationId: "#{@application.id}", reason: "no" }) { userErrors { code } } }
    GQL
    assert_equal "not_found", data.dig("data", "rejectApplication", "userErrors", 0, "code")
    assert_equal "active", within_org { @application.reload.status }
  end

  test "mutations need their permission" do
    data = gql(<<~GQL, token: personal_token(%w[jobs:read]))
      mutation { rejectApplication(input: { applicationId: "#{@application.id}", reason: "no" }) { userErrors { code } } }
    GQL
    assert_equal "insufficient_permission", data.dig("errors", 0, "extensions", "code")
    assert_equal "active", within_org { @application.reload.status }
  end

  test "an agent's GraphQL write is attributed to the agent in audit" do
    agent = within_org { Agent.create!(owner_membership: @provisioned[:membership], name: "Screener", scopes: %w[applications:transition people:read]) }
    token = within_org { CredentialIssuer.call(kind: "agent", name: "t", agent: agent, audit: false).token }

    data = gql(<<~GQL, token: token)
      mutation { rejectApplication(input: { applicationId: "#{@application.id}", reason: "not a fit" }) { application { status } userErrors { code } } }
    GQL
    assert_equal "rejected", data.dig("data", "rejectApplication", "application", "status")

    audit = AuditEvent.unscoped.where(organization_id: @org.id, resource_id: @application.id, action: "application.reject").sole
    assert_equal "agent", audit.actor_type
    assert_equal agent.id, audit.actor_id
    assert_equal @owner.id, audit.on_behalf_of_id
  end

  test "browser sessions may only run persisted queries" do
    session = within_org { CredentialIssuer.call(kind: "session", name: "s", user: @owner, expires_at: 1.hour.from_now, audit: false).token }
    post "/graphql", params: { query: "{ viewer { actorType } }" }, headers: bearer(session), as: :json
    assert_response :forbidden
    assert_equal "persisted_query_required", response.parsed_body["code"]

    document = "query Viewer { viewer { actorType } }"
    PersistedQueries.instance_variable_set(:@all, { PersistedQueries.digest(document) => document }.freeze)
    post "/graphql", params: { id: PersistedQueries.digest(document) }, headers: bearer(session), as: :json
    assert_response :success
    assert_equal "user", response.parsed_body.dig("data", "viewer", "actorType")

    post "/graphql", params: { id: "nope" }, headers: bearer(session), as: :json
    assert_response :not_found
  end

  test "overly deep queries are refused" do
    deep = "{ applications(first: 1) { nodes { job { applications(first: 1) { nodes { job { applications(first: 1) " \
           "{ nodes { job { applications(first: 1) { nodes { job { title } } } } } } } } } } } } }"
    data = gql(deep, token: personal_token(%w[jobs:read]))
    assert data["errors"].any? { |e| e["message"].match?(/depth|complexity/i) }, data["errors"].inspect
  end

  private

  def gql(query, token:, variables: {})
    post "/graphql", params: { query: query, variables: variables }, headers: bearer(token), as: :json
    assert_response :success
    response.parsed_body
  end

  def bearer(token) = { "Authorization" => "Bearer #{token}" }

  def personal_token(scopes)
    within_org { CredentialIssuer.call(kind: "personal", name: "p", user: @owner, scopes: scopes, audit: false).token }
  end

  # A personal token with every scope: effectively the user's role.
  def session_like_token(user)
    within_org { CredentialIssuer.call(kind: "personal", name: "p", user: user, scopes: Scopes::ALL, audit: false).token }
  end

  def within_org
    Current.organization_id = @org.id
    Current.actor_id = @owner.id
    yield
  ensure
    Current.reset
  end
end
