# frozen_string_literal: true

require "test_helper"

class V1::SourcingAgentTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "AgentCo", slug: "ag-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@ag.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    @viewer = @provisioned[:membership]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@ag.test", provider: "sandbox",
      status: "connected", secret_ref: "sandbox://mailbox", user: @user)
    @agent = Agent.create!(owner_membership: @viewer, name: "Sourcer", scopes: %w[people:read])
    @sequence = Sequence.find_by!(key: "starter-outreach")
    template = PipelineTemplate.create!(key: "job", name: "Job", object_type: "job")
    template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    @old = Job.create!(title: "Old role", status: "closed", pipeline: Pipeline.build_from_template!(template: template))
    @job = Job.create!(title: "Staff Backend", status: "active", pipeline: Pipeline.build_from_template!(template: template),
      criteria: [ { "id" => "c1", "label" => "Backend", "kind" => "must", "match" => { "q" => "backend" } } ])
    @people = 4.times.map do |i|
      p = PersonMatcher.find_or_create(display_name: "Silver #{i}", email: "s#{i}@ag.test", viewer: @viewer).person
      p.update!(headline: "Senior backend engineer", city: "Philadelphia")
      Application.create!(person: p, job: @old, pipeline: @old.pipeline, pipeline_version: @old.pipeline.version,
        current_stage_key: "applied", status: "rejected")
      p
    end
    @people.last.update!(do_not_contact: true)
  end

  teardown { Current.reset }

  def headers
    { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id, "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }
  end

  def run_agent(extra = {})
    post "/v1/jobs/#{@job.id}/sourcing_agent/run", headers: headers, as: :json,
      params: { sequence_id: @sequence.id, agent_id: @agent.id }.merge(extra)
    assert_response :success
    response.parsed_body
  end

  test "default policy: the agent proposes with drafted openers and nothing is enrolled or sent" do
    body = run_agent
    assert_equal "approval_required", body["policy"]
    assert_equal 3, body["proposed"].size
    assert_equal 0, body["auto_enrolled"]
    assert_equal 0, SequenceEnrollment.count
    assert_equal 0, ScheduledMessage.count
    proposal = AgentProposal.find(body["proposed"].first)
    assert_match(/\AHi Silver/, proposal.draft_opener)
    assert_equal @user.id, proposal.on_behalf_of_user_id
    audit = AuditEvent.where(action: "agent_proposal.created").first
    assert_equal "agent", audit.actor_type
    assert_equal @agent.id, audit.actor_id
    assert_equal @user.id, audit.on_behalf_of_id
  end

  test "running twice does not propose the same people again" do
    run_agent
    assert_equal 0, run_agent["proposed"].size
  end

  test "a person approves some and rejects one; approval enrolls with the accepted opener" do
    ids = run_agent["proposed"]
    post "/v1/agent_proposals/bulk_approve", params: { ids: ids.first(2) }, headers: headers, as: :json
    assert_response :success
    assert_equal 2, response.parsed_body["approved"]
    post "/v1/agent_proposals/#{ids.last}/reject", params: { reason: "too junior" }, headers: headers, as: :json
    assert_equal "rejected", response.parsed_body["status"]
    assert_equal 2, SequenceEnrollment.count
    assert_equal "not_a_fit", RediscoveryCandidate.find(AgentProposal.find(ids.last).rediscovery_candidate_id).status
    post "/v1/agent_proposals/#{ids.first}/approve", headers: headers, as: :json
    assert_response :unprocessable_entity # already decided
    get "/v1/agent_proposals", params: { status: "approved" }, headers: headers
    assert_equal 2, response.parsed_body["data"].size
  end

  test "the opener token renders in the sent message" do
    template = MessageTemplate.find_by!(key: "starter-intro")
    template.update!(body: "{{opener}}\n\nWould you like to talk?")
    id = run_agent["proposed"].first
    post "/v1/agent_proposals/#{id}/approve", params: { opener: "Hi there, loved your Go talk." }, headers: headers, as: :json
    assert_response :success
    assert_includes ScheduledMessage.order(:created_at).last.body, "loved your Go talk"
  end

  test "unattended policy enrolls straight away, still through outreach checks" do
    @org.merge_settings!("agent_send_policy" => "unattended")
    body = run_agent
    assert_equal 3, body["auto_enrolled"]
    assert_equal 3, SequenceEnrollment.count
    assert_equal "approved", AgentProposal.first.status
  end

  test "agent policy values are validated" do
    patch "/v1/organizations/#{@org.id}", params: { organization: { agent_send_policy: "yolo" } }, headers: headers, as: :json
    assert_response :unprocessable_entity
    patch "/v1/organizations/#{@org.id}", params: { organization: { agent_send_policy: "unattended" } }, headers: headers, as: :json
    assert_response :success
    assert_equal "unattended", response.parsed_body["agent_send_policy"]
  end

  test "the nightly job runs for the configured agent" do
    @org.merge_settings!("sourcing_agent_id" => @agent.id, "sourcing_agent_sequence_id" => @sequence.id)
    SourcingAgentJob.perform_now
    assert_equal 3, AgentProposal.where(status: "pending").count
  end
end
