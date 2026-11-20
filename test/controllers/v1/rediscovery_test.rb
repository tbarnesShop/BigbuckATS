# frozen_string_literal: true

require "test_helper"

class V1::RediscoveryTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "RediscoCo", slug: "rd-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@rd.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    @viewer = @provisioned[:membership]
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@rd.test", provider: "sandbox",
      status: "connected", secret_ref: "sandbox://mailbox", user: @user)
    template = PipelineTemplate.create!(key: "job", name: "Job", object_type: "job")
    template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    @old = Job.create!(title: "Old role", status: "closed", pipeline: Pipeline.build_from_template!(template: template))
    @secret = Job.create!(title: "Secret role", status: "closed", confidential: true, code_name: "X",
      pipeline: Pipeline.build_from_template!(template: template))
    @job = Job.create!(title: "Staff Backend", status: "active", pipeline: Pipeline.build_from_template!(template: template))
    @ana = person("Ana Silver", "ana@rd.test", headline: "Staff backend engineer, Go and Kubernetes", city: "Philadelphia")
    @ben = person("Ben Weak", "ben@rd.test", headline: "Frontend developer", city: "Boston")
    @cy = person("Cy Pool", "cy@rd.test", headline: "Backend engineer working in Go", city: "Philadelphia")
    apply(@ana, @old, "rejected")
    apply(@ben, @old, "rejected")
    pipeline = SourcingPipeline.default!
    pool = Project.create!(name: "Go bench", pipeline: pipeline)
    PoolAdder.call(project: pool, people: [ @cy ])
    PersonTagger.add!(person: @cy, tag: Tag.find_or_create_named!("go"))
  end

  teardown { Current.reset }

  def person(name, email, **attrs)
    p = PersonMatcher.find_or_create(display_name: name, email: email, viewer: @viewer).person
    p.update!(attrs)
    p
  end

  def apply(person, job, status)
    Application.create!(person: person, job: job, pipeline: job.pipeline, pipeline_version: job.pipeline.version,
      current_stage_key: "applied", status: status)
  end

  def headers
    { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id, "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }
  end

  def set_criteria
    put "/v1/jobs/#{@job.id}/rediscovery/criteria", headers: headers, as: :json, params: { criteria: [
      { label: "Backend", kind: "must", match: { q: "backend" } },
      { label: "Go", kind: "nice", match: { q: "go" } },
      { label: "Philadelphia", kind: "nice", match: { location: "Philadelphia" } }
    ] }
    assert_response :success
  end

  test "criteria validate and persist" do
    put "/v1/jobs/#{@job.id}/rediscovery/criteria", headers: headers, as: :json, params: { criteria: [ { label: "x", kind: "maybe", match: { q: "x" } } ] }
    assert_response :unprocessable_entity
    set_criteria
    assert_equal 3, response.parsed_body["criteria"].size
    get "/v1/jobs/#{@job.id}/rediscovery/criteria", headers: headers
    assert_equal 3, response.parsed_body["criteria"].size
  end

  test "running needs criteria, then queues only people who meet every must-have, with evidence" do
    post "/v1/jobs/#{@job.id}/rediscovery/run", headers: headers, as: :json
    assert_response :unprocessable_entity
    set_criteria
    post "/v1/jobs/#{@job.id}/rediscovery/run", headers: headers, as: :json
    assert_response :success
    assert_equal 2, response.parsed_body["created"]
    get "/v1/jobs/#{@job.id}/rediscovery/queue", headers: headers
    rows = response.parsed_body["data"]
    assert_equal [ "Ana Silver", "Cy Pool" ], rows.map { |r| r.dig("person", "display_name") }.sort
    ana = rows.find { |r| r.dig("person", "display_name") == "Ana Silver" }
    assert_equal "silver_medalist", ana["bucket"]
    assert ana["verdicts"].all? { |v| v["met"] }
    assert ana["verdicts"].first["evidence"].first.start_with?("headline:")
    cy = rows.find { |r| r.dig("person", "display_name") == "Cy Pool" }
    assert_equal "high_fit", cy["bucket"]
    assert_operator ana["score"], :>, cy["score"]
  end

  test "review actions stick across runs; add_to_pool lands in the job's rediscovery pool" do
    set_criteria
    post "/v1/jobs/#{@job.id}/rediscovery/run", headers: headers, as: :json
    candidate = RediscoveryCandidate.find_by!(person_id: @ana.id)
    post "/v1/rediscovery_candidates/#{candidate.id}/review", headers: headers, as: :json, params: { review_action: "add_to_pool", feedback: "great fit" }
    assert_response :success
    assert_equal "added_to_pool", response.parsed_body["status"]
    assert_equal 1, response.parsed_body.dig("outcome", "added")
    assert ProjectMember.joins(:project).exists?(person_id: @ana.id, projects: { name: "Staff Backend – rediscovery" })

    other = RediscoveryCandidate.find_by!(person_id: @cy.id)
    post "/v1/rediscovery_candidates/#{other.id}/review", headers: headers, as: :json, params: { review_action: "not_a_fit" }
    post "/v1/jobs/#{@job.id}/rediscovery/run", headers: headers, as: :json
    assert_equal 0, response.parsed_body["created"]
    assert_equal "not_a_fit", other.reload.status

    get "/v1/jobs/#{@job.id}/rediscovery/queue", params: { status: "pending" }, headers: headers
    assert_empty response.parsed_body["data"]
    post "/v1/rediscovery_candidates/#{candidate.id}/review", headers: headers, as: :json, params: { review_action: "launch" }
    assert_response :unprocessable_entity
  end

  test "do-not-contact people, recent rejections and active applicants are excluded" do
    set_criteria
    @ana.update!(do_not_contact: true)
    apply(@cy, @job, "rejected")
    post "/v1/jobs/#{@job.id}/rediscovery/run", headers: headers, as: :json
    assert_equal 0, response.parsed_body["created"]
  end

  test "a viewer without job.read_confidential never sees confidential history" do
    dee = person("Dee Secret", "dee@rd.test", headline: "Staff backend engineer", city: "Philadelphia")
    apply(dee, @secret, "rejected")
    refute_includes ResourceVisibility.applications.pluck(:job_id), @secret.id
    @job.update!(criteria: [ { "id" => "c1", "label" => "Backend", "kind" => "must", "match" => { "q" => "backend" } } ])
    # Engine called directly: no principal, so confidential jobs are hidden (header-auth requests are legacy and see all).
    RediscoveryEngine.run!(job: @job, viewer: @viewer)
    assert_not RediscoveryCandidate.exists?(person_id: dee.id)
  end
end
