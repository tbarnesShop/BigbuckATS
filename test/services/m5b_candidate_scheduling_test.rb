# frozen_string_literal: true

require "test_helper"

# M5b proving test: candidate books a panel from a link; decline replaced from pool.
class M5bCandidateSchedulingTest < ActiveSupport::TestCase
  setup do
    @fake = CalendarClient::Fake.new
    CalendarClient.backend = @fake

    @provisioned = OrganizationProvisioner.call(
      name: "CandSched", slug: "cs-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@cs.test", owner_name: "O"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id

    @users = Array.new(4) { |i| User.create!(email: "u#{i}-#{SecureRandom.hex(2)}@cs.test", name: "U#{i}") }
    @hm, @p1, @p2, @p3 = @users
    @profiles = @users.map { |u| { user_id: u.id, paused: false } }
    @emails = @users.index_by(&:id).transform_values(&:email)

    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [
      { "key" => "onsite", "name" => "Onsite", "type" => "interview",
        "interviews" => [
          { "key" => "hm", "name" => "HM" },
          { "key" => "pool", "name" => "Pool" }
        ] }
    ])
    pipeline = Pipeline.build_from_template!(template: template)
    job = Job.create!(title: "Eng", status: "active", pipeline: pipeline)
    person = Person.create!(display_name: "Cand", primary_email: "cand@cs.test")
    @application = ApplicationCreator.call(job: job, person: person)

    @defs = [
      { key: "hm", duration_minutes: 30, count: 1, candidate_user_ids: [ @hm.id ] },
      { key: "pool", duration_minutes: 45, count: 1, candidate_user_ids: [ @p1.id, @p2.id, @p3.id ] }
    ]
    @start = Time.utc(2026, 11, 2, 9, 0, 0)
    @finish = @start + 5.days
  end

  teardown do
    CalendarClient.backend = nil
    Current.reset
  end

  test "booking uses the current stage and avoids an existing local booking" do
    @application.pipeline.update!(resolved_stages: [ { "key" => "phone", "name" => "Phone screen", "interviews" => [ { "key" => "hm" } ] } ])
    @application.update!(current_stage_key: "phone")
    first = PanelBooking.suggest_and_book!(application: @application, interview_defs: [ @defs.first ], profiles: @profiles,
      organizer_calendar: "org@cs.test", user_emails: @emails, search_start: @start, search_end: @finish)
    second = PanelBooking.suggest_and_book!(application: @application, interview_defs: [ @defs.first ], profiles: @profiles,
      organizer_calendar: "org@cs.test", user_emails: @emails, search_start: @start, search_end: @finish)
    assert_equal "phone", first.interviews.first.stage_key
    assert second.interviews.first.starts_at >= first.interviews.first.ends_at
  end

  test "demo booking captures the calendar event without a configured backend" do
    DemoSandbox.create!(surface: "ui", organization_id: Current.organization_id, generation: 1, resets_at: 1.hour.from_now)
    CalendarClient.backend = nil
    result = PanelBooking.suggest_and_book!(application: @application, interview_defs: [ @defs.first ], profiles: @profiles,
      organizer_calendar: "org@cs.test", user_emails: @emails, search_start: @start, search_end: @finish)
    assert result.booked
    assert_match(/^demo_evt_/, result.interviews.first.calendar_event_id)
  end

  test "candidate books a panel from a self-schedule link" do
    issued = SelfSchedule.create_link!(application: @application, interview_keys: %w[hm pool])
    assert issued[:token].present?

    result = SelfSchedule.book!(
      token: issued[:token],
      interview_defs: @defs,
      profiles: @profiles,
      organizer_calendar: "org@cs.test",
      user_emails: @emails,
      search_start: @start,
      search_end: @finish
    )
    assert result.booked
    assert_equal 2, result.interviews.size
    assert issued[:link].reload.used_at.present?

    assert_raises(ArgumentError) do
      SelfSchedule.book!(
        token: issued[:token],
        interview_defs: @defs,
        profiles: @profiles,
        organizer_calendar: "org@cs.test",
        user_emails: @emails,
        search_start: @start,
        search_end: @finish
      )
    end
  end

  test "interviewer decline is replaced from the pool without re-booking time" do
    result = PanelBooking.suggest_and_book!(
      application: @application,
      interview_defs: @defs,
      profiles: @profiles,
      organizer_calendar: "org@cs.test",
      user_emails: @emails,
      search_start: @start,
      search_end: @finish
    )
    pool_interview = result.interviews.find { |i| i.interview_key == "pool" }
    declined = pool_interview.interviewer_user_ids.first
    original_start = pool_interview.starts_at

    pool_interview.update!(interviewer_pool_id: "pool-a", on_decline: "replace_from_pool")
    outcome = DeclineReplacement.call(
      interview: pool_interview,
      declined_user_id: declined,
      pool_user_ids: [ @p1.id, @p2.id, @p3.id ],
      profiles: @profiles,
      user_emails: @emails,
      organizer_calendar: "org@cs.test"
    )
    assert outcome.replaced
    assert_equal original_start, outcome.interview.starts_at
    assert_not_includes outcome.interview.interviewer_user_ids, declined
    assert OutboxEvent.exists?(event_type: "interview.interviewer_replaced")
  end

  test "ics builder emits updatable uid and sequence" do
    ics = IcsBuilder.event(
      uid: "interview-1@bigbuck",
      sequence: 2,
      starts_at: @start,
      ends_at: @start + 30.minutes,
      summary: "HM chat",
      organizer_email: "recruiting@cs.test",
      attendee_emails: [ "cand@cs.test" ]
    )
    assert_includes ics, "UID:interview-1@bigbuck"
    assert_includes ics, "SEQUENCE:2"
    assert_includes ics, "ATTENDEE:mailto:cand@cs.test"
  end

  test "availability request with auto_book schedules the panel" do
    issued = SelfSchedule.create_link!(
      application: @application, interview_keys: %w[hm pool], kind: "availability"
    )
    outcome = AvailabilityRequestSubmitter.call(
      token: issued[:token],
      windows: [ { "start" => @start.iso8601, "end" => @finish.iso8601 } ],
      candidate_time_zone: "UTC",
      auto_book: true,
      interview_defs: @defs,
      profiles: @profiles,
      organizer_calendar: "org@cs.test",
      user_emails: @emails
    )
    assert outcome.request.submitted_at.present?
    assert outcome.booking.booked
    assert_equal 2, Interview.where(application_id: @application.id, status: "scheduled").count
  end

  test "scorecard nudge lists interviewers missing submitted feedback" do
    interview = Interview.create!(
      application: @application, stage_key: "onsite", interview_key: "hm",
      status: "completed", starts_at: 1.day.ago, ends_at: 1.day.ago + 30.minutes,
      interviewer_user_ids: [ @hm.id, @p1.id ]
    )
    ScorecardSubmitter.call(interview: interview, user: @hm, rating: "yes")
    due = ScorecardNudge.due(as_of: Time.current)
    assert due.any? { |row| row[:interview_id] == interview.id && row[:user_id] == @p1.id }
    assert due.none? { |row| row[:interview_id] == interview.id && row[:user_id] == @hm.id }
  end
end
