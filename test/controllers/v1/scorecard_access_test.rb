# frozen_string_literal: true

require "test_helper"

# Feedback is assigned to the interviewers booked on an interview. Who may write, read and correct it,
# checked with real role-bound credentials (header auth off, as production runs).
class V1::ScorecardAccessTest < ActionDispatch::IntegrationTest
  setup do
    @header_auth_was = Rails.configuration.x.header_auth
    Rails.configuration.x.header_auth = false

    @provisioned = OrganizationProvisioner.call(
      name: "Panel", slug: "panel-#{SecureRandom.hex(4)}",
      owner_email: "owner-#{SecureRandom.hex(4)}@panel.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @owner = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @owner.id
    @recruiter = member("recruiter")
    @ana = member("hiring_manager")
    @ben = member("hiring_manager")
    @outsider = member("hiring_manager")
    @manager = member("hiring_manager")

    ScorecardRubric.create!(key: "coding", name: "Coding", attributes_spec: [
      { "key" => "problem-solving", "label" => "Problem solving" },
      { "key" => "communication", "label" => "Communication", "required" => false }
    ])
    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [
      { "key" => "onsite", "name" => "Onsite", "type" => "interview",
        "interviews" => [
          { "key" => "coding", "name" => "Coding", "required" => true, "rubric_key" => "coding" },
          { "key" => "chat", "name" => "Chat", "required" => false }
        ] },
      { "key" => "offer", "name" => "Offer", "type" => "offer" }
    ])
    @job = Job.create!(title: "Eng", status: "active", pipeline: Pipeline.build_from_template!(template: template))
    team = HiringTeam.create!(job: @job)
    HiringTeamMember.create!(hiring_team: team, user: @manager, team_role: "hiring-manager")
    @application = ApplicationCreator.call(job: @job, person: Person.create!(display_name: "Cand"))
    @coding = Interview.create!(
      application: @application, stage_key: "onsite", interview_key: "coding", status: "completed",
      starts_at: 2.hours.ago, ends_at: 1.hour.ago, interviewer_user_ids: [ @ana.id, @ben.id ]
    )
    @unassigned = Interview.create!(
      application: @application, stage_key: "onsite", interview_key: "chat", status: "completed",
      starts_at: 2.hours.ago, ends_at: 1.hour.ago, interviewer_user_ids: []
    )
    @tokens = {}
    Current.reset
  end

  teardown do
    Rails.configuration.x.header_auth = @header_auth_was
    Current.reset
  end

  test "only the assigned interviewers can submit, and an unassigned interview takes no feedback" do
    submit(@outsider, @coding)
    assert_response :unprocessable_entity
    assert_equal "not_an_interviewer", response.parsed_body["title"]

    submit(@ana, @unassigned, attribute_ratings: nil)
    assert_response :unprocessable_entity
    assert_equal "interview_unassigned", response.parsed_body["title"]

    submit(@owner, @unassigned, attribute_ratings: nil)
    assert_response :unprocessable_entity, "an owner cannot write feedback for an interview they were not on"

    submit(@ana, @coding)
    assert_response :created
    assert_equal @ana.id, response.parsed_body["user_id"]
  end

  test "an interviewer reads the panel's feedback only after submitting their own" do
    submit(@ana, @coding, notes: "Ana's notes")
    assert_response :created

    assert_empty listed(@ben), "Ben has not submitted, so Ana's scorecard stays hidden"
    assert_empty listed(@outsider)

    submit(@ben, @coding, notes: "Ben's notes")
    assert_response :created
    assert_equal [ @ana.id, @ben.id ].sort, listed(@ben).map { |row| row["user_id"] }.sort
    assert_equal [ @ana.id, @ben.id ].sort, listed(@ana).map { |row| row["user_id"] }.sort
    assert_empty listed(@outsider)
  end

  test "recruiters and the job's hiring manager read every scorecard" do
    submit(@ana, @coding)

    assert_equal [ @ana.id ], listed(@recruiter).map { |row| row["user_id"] }
    assert_equal [ @ana.id ], listed(@manager).map { |row| row["user_id"] }
    assert_equal [ @ana.id ], listed(@owner).map { |row| row["user_id"] }
  end

  test "everyone on the application sees who has submitted, not what they wrote" do
    submit(@ana, @coding)

    get "/v1/applications/#{@application.id}/interviews", headers: bearer(@outsider)
    assert_response :success
    coding = response.parsed_body["data"].find { |row| row["id"] == @coding.id }
    assert_equal [ @ana.id ], coding["feedback_submitted_user_ids"]
  end

  test "the author corrects their own feedback and it stays theirs" do
    submit(@ana, @coding, rating: "yes")
    id = response.parsed_body["id"]
    assert response.parsed_body["can_edit"]

    patch "/v1/scorecards/#{id}",
          params: { scorecard: { rating: "no", notes: "Changed my mind", attribute_ratings: { "problem-solving" => "no" } } },
          headers: bearer(@ana), as: :json
    assert_response :success
    assert_equal "no", response.parsed_body["rating"]
    assert_equal @ana.id, response.parsed_body["user_id"]
    assert_equal 1, within_org { Scorecard.where(interview_id: @coding.id).count }
  end

  test "only scorecard.manage corrects someone else's feedback, and the audit names the editor" do
    submit(@ana, @coding, rating: "yes")
    id = response.parsed_body["id"]
    body = { scorecard: { rating: "mixed", notes: "Corrected", attribute_ratings: { "problem-solving" => "mixed" } } }

    submit(@ben, @coding)
    patch "/v1/scorecards/#{id}", params: body, headers: bearer(@ben), as: :json
    assert_response :forbidden

    patch "/v1/scorecards/#{id}", params: body, headers: bearer(@recruiter), as: :json
    assert_response :forbidden
    refute listed(@recruiter).find { |row| row["id"] == id }["can_edit"]

    patch "/v1/scorecards/#{id}", params: body, headers: bearer(@owner), as: :json
    assert_response :success
    assert_equal "mixed", response.parsed_body["rating"]
    assert_equal @ana.id, response.parsed_body["user_id"], "authorship does not move to the editor"

    audit = within_org { AuditEvent.where(resource_type: "Scorecard", resource_id: id).order(:created_at).last }
    assert_equal "scorecard.updated", audit.action
    assert_equal @owner.id, audit.actor_id
  end

  test "a correction still has to complete the rubric and use a known rating" do
    submit(@ana, @coding)
    id = response.parsed_body["id"]

    patch "/v1/scorecards/#{id}", params: { scorecard: { rating: "yes" } }, headers: bearer(@ana), as: :json
    assert_response :unprocessable_entity
    assert_match(/rubric_incomplete:problem-solving/, response.parsed_body["title"])

    patch "/v1/scorecards/#{id}",
          params: { scorecard: { rating: "superb", attribute_ratings: { "problem-solving" => "yes" } } },
          headers: bearer(@ana), as: :json
    assert_response :unprocessable_entity
    assert_equal "invalid_rating", response.parsed_body["title"]
  end

  test "a rubric can be edited without changing its key" do
    rubric = within_org { ScorecardRubric.find_by!(key: "coding") }
    body = { scorecard_rubric: { name: "Coding interview", guidance: "Rate what you saw.", attributes_spec: [
      { key: "problem-solving", label: "Problem solving", required: true },
      { key: "testing", label: "Testing", required: false }
    ] } }

    patch "/v1/scorecard_rubrics/#{rubric.id}", params: body, headers: bearer(@recruiter), as: :json
    assert_response :forbidden

    patch "/v1/scorecard_rubrics/#{rubric.id}", params: body, headers: bearer(@owner), as: :json
    assert_response :success
    assert_equal "coding", response.parsed_body["key"]
    assert_equal "Coding interview", response.parsed_body["name"]
    assert_equal %w[problem-solving testing], response.parsed_body["attributes_spec"].map { |row| row["key"] }

    patch "/v1/scorecard_rubrics/#{rubric.id}",
          params: { scorecard_rubric: { attributes_spec: [ { key: "a" }, { key: "a" } ] } },
          headers: bearer(@owner), as: :json
    assert_response :unprocessable_entity
  end

  private

  def member(role)
    user = User.create!(email: "#{role}-#{SecureRandom.hex(3)}@panel.test", name: role.humanize)
    Membership.create!(user: user, role: @provisioned[:roles].fetch(role), status: "active")
    user
  end

  def within_org
    Current.organization_id = @org.id
    yield
  ensure
    Current.reset
  end

  def bearer(user)
    @tokens[user.id] ||= within_org do
      CredentialIssuer.call(kind: "session", name: "test session", user: user, scopes: [],
                            expires_at: 1.hour.from_now, audit: false)
    end
    token = @tokens[user.id]
    { "Authorization" => "Bearer #{token.respond_to?(:token) ? token.token : token}" }
  end

  def submit(user, interview, rating: "yes", notes: nil, attribute_ratings: { "problem-solving" => "yes" })
    post "/v1/scorecards",
         params: { scorecard: { interview_id: interview.id, rating: rating, notes: notes,
                                attribute_ratings: attribute_ratings }.compact },
         headers: bearer(user), as: :json
  end

  def listed(user)
    get "/v1/scorecards", params: { application_id: @application.id }, headers: bearer(user)
    assert_response :success
    response.parsed_body["data"]
  end
end
