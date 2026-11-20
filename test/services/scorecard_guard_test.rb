# frozen_string_literal: true

require "test_helper"

# Missing feedback is reported but does not hold a stage move, unless the stage's exit rules ask for it.
class ScorecardGuardTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "GuardCo", slug: "g-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@g.test", owner_name: "O"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id

    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [
      { "key" => "onsite", "name" => "Onsite", "type" => "interview",
        "interviews" => [
          { "key" => "hm", "name" => "HM", "required" => true },
          { "key" => "optional", "name" => "Optional", "required" => false }
        ] },
      { "key" => "offer", "name" => "Offer", "type" => "offer" }
    ])
    @pipeline = Pipeline.build_from_template!(template: template)
    @job = Job.create!(title: "Eng", status: "active", pipeline: @pipeline)
    @person = Person.create!(display_name: "Cand")
    @application = ApplicationCreator.call(job: @job, person: @person)
    @interviewer = User.create!(email: "iv-#{SecureRandom.hex(2)}@g.test", name: "IV")

    @hm = Interview.create!(
      application: @application, stage_key: "onsite", interview_key: "hm",
      status: "completed", interviewer_user_ids: [ @interviewer.id ]
    )
    Interview.create!(
      application: @application, stage_key: "onsite", interview_key: "optional",
      status: "completed", interviewer_user_ids: [ @interviewer.id ]
    )
  end

  teardown { Current.reset }

  test "missing feedback is reported and does not hold the move" do
    missing = StageGuards.missing_scorecards(subject: @application, stage_key: "onsite")
    assert_equal [ "hm" ], missing.map { |row| row["key"] }
    refute StageGuards.scorecards_required?(subject: @application, stage_key: "onsite")

    SubjectTransitions.move(subject: @application, to_stage_key: "offer")
    assert_equal "offer", @application.reload.current_stage_key
  end

  test "submitted feedback clears the missing list" do
    ScorecardSubmitter.call(interview: @hm, user: @interviewer, rating: "yes", notes: "strong")
    assert_empty StageGuards.missing_scorecards(subject: @application, stage_key: "onsite")
  end

  test "a stage whose exit rules name scorecards_submitted still holds the move" do
    stages = @pipeline.resolved_stages.map do |stage|
      stage["key"] == "onsite" ? stage.merge("exit" => [ { "scorecards_submitted" => { "interviews" => "required" } } ]) : stage
    end
    @pipeline.update!(resolved_stages: stages)
    @application.reload
    assert StageGuards.scorecards_required?(subject: @application, stage_key: "onsite")

    error = assert_raises(StageGuards::Failed) do
      SubjectTransitions.move(subject: @application, to_stage_key: "offer")
    end
    assert_match(/scorecards_submitted:hm/, error.message)

    ScorecardSubmitter.call(interview: @hm, user: @interviewer, rating: "yes", notes: "strong")
    SubjectTransitions.move(subject: @application, to_stage_key: "offer")
    assert_equal "offer", @application.reload.current_stage_key
  end

  test "feedback opens when the interview starts" do
    upcoming = Interview.create!(
      application: @application, stage_key: "onsite", interview_key: "hm", status: "scheduled",
      starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour, interviewer_user_ids: [ @interviewer.id ]
    )
    error = assert_raises(ArgumentError) do
      ScorecardSubmitter.call(interview: upcoming, user: @interviewer, rating: "yes")
    end
    assert_equal "feedback_before_interview", error.message

    upcoming.update!(starts_at: 5.minutes.ago, ends_at: 55.minutes.from_now)
    assert_equal "submitted", ScorecardSubmitter.call(interview: upcoming, user: @interviewer, rating: "yes").status
  end

  test "only assigned interviewers can submit feedback" do
    outsider = User.create!(email: "out-#{SecureRandom.hex(2)}@g.test", name: "Out")
    interview = Interview.create!(
      application: @application, stage_key: "onsite", interview_key: "hm", status: "completed",
      starts_at: 1.hour.ago, ends_at: Time.current, interviewer_user_ids: [ @interviewer.id ]
    )
    error = assert_raises(ArgumentError) do
      ScorecardSubmitter.call(interview: interview, user: outsider, rating: "yes")
    end
    assert_equal "not_an_interviewer", error.message
  end

  test "an empty exit list holds nothing" do
    template = PipelineTemplate.create!(key: "strict", name: "Strict", object_type: "job")
    template.publish!(stages: [
      { "key" => "loop", "name" => "Loop", "type" => "interview", "exit" => [],
        "interviews" => [ { "key" => "coding", "name" => "Coding", "required" => true } ] },
      { "key" => "done", "name" => "Done", "type" => "offer" }
    ])
    pipeline = Pipeline.build_from_template!(template: template)
    job = Job.create!(title: "S", status: "active", pipeline: pipeline)
    app = ApplicationCreator.call(job: job, person: @person)
    Interview.create!(application: app, stage_key: "loop", interview_key: "coding", status: "completed")

    assert_equal [ "coding" ], StageGuards.missing_scorecards(subject: app, stage_key: "loop").map { |row| row["key"] }
    SubjectTransitions.move(subject: app, to_stage_key: "done")
    assert_equal "done", app.reload.current_stage_key
  end
end
