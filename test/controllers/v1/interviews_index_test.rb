# frozen_string_literal: true

require "test_helper"

class V1::InterviewsIndexTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "IvCo", slug: "iv-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@iv.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id

    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [
      { "key" => "onsite", "name" => "Onsite", "type" => "interview",
        "interviews" => [ { "key" => "hm", "name" => "HM", "required" => true } ] }
    ])
    @job = Job.create!(title: "Eng", status: "active", pipeline: Pipeline.build_from_template!(template: template))
    @application = ApplicationCreator.call(job: @job, person: Person.create!(display_name: "Cand"))
    @other = User.create!(email: "x-#{SecureRandom.hex(2)}@iv.test", name: "Other")

    @soon = interview("scheduled", 2.days.from_now, [ @user.id ])
    @later = interview("scheduled", 5.days.from_now, [ @user.id ])
    @past = interview("completed", 3.days.ago, [ @user.id ])
    @theirs = interview("scheduled", 1.day.from_now, [ @other.id ])
    @waiting = interview("needs_attention", nil, [ @user.id ])
  end

  teardown { Current.reset }

  def interview(status, starts_at, interviewers)
    Interview.create!(
      application: @application, stage_key: "onsite", interview_key: "hm", status: status,
      starts_at: starts_at, ends_at: starts_at && (starts_at + 1.hour), interviewer_user_ids: interviewers
    )
  end

  def headers
    { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
  end

  def ids(tab = nil)
    get "/v1/interviews", params: tab ? { tab: tab } : {}, headers: headers
    assert_response :success
    response.parsed_body["data"].map { |row| row["id"] }
  end

  test "lists every interview soonest first, unscheduled last" do
    assert_equal [ @past.id, @theirs.id, @soon.id, @later.id, @waiting.id ], ids
  end

  test "rows carry the application and job ids" do
    get "/v1/interviews", headers: headers
    row = response.parsed_body["data"].find { |r| r["id"] == @soon.id }
    assert_equal @application.id, row["application_id"]
    assert_equal @job.id, row["job_id"]
  end

  test "upcoming is scheduled and still ahead" do
    assert_equal [ @theirs.id, @soon.id, @later.id ], ids("upcoming")
  end

  test "schedule is waiting or needing attention" do
    assert_equal [ @waiting.id ], ids("schedule")
  end

  test "mine is interviews I am on" do
    assert_equal [ @past.id, @soon.id, @later.id, @waiting.id ], ids("mine")
  end

  test "feedback is mine that have started and still need my scorecard" do
    assert_equal [ @past.id ], ids("feedback"), "an interview that has not happened yet owes no feedback"
    # Current is reset after each request in integration tests.
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    ScorecardSubmitter.call(interview: @past, user: @user, rating: "yes")
    assert_empty ids("feedback")
  end

  test "an unknown tab is refused" do
    get "/v1/interviews", params: { tab: "bogus" }, headers: headers
    assert_response :unprocessable_entity
    assert_equal "invalid_interview", JSON.parse(response.body)["code"]
  end
end
