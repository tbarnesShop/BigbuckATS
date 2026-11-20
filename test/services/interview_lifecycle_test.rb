# frozen_string_literal: true

require "test_helper"

class InterviewLifecycleTest < ActiveSupport::TestCase
  setup do
    @fake = CalendarClient::Fake.new
    CalendarClient.backend = @fake

    @provisioned = OrganizationProvisioner.call(
      name: "LifeCo", slug: "l-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@l.test", owner_name: "O"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id

    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [
      { "key" => "onsite", "name" => "Onsite", "type" => "interview",
        "interviews" => [ { "key" => "hm", "name" => "HM" } ] }
    ])
    pipeline = Pipeline.build_from_template!(template: template)
    job = Job.create!(title: "Eng", status: "active", pipeline: pipeline)
    person = Person.create!(display_name: "Cand")
    @application = ApplicationCreator.call(job: job, person: person)
    @user = User.create!(email: "u-#{SecureRandom.hex(2)}@l.test", name: "U")
    @emails = { @user.id => @user.email }

    starts = Time.utc(2026, 11, 3, 10, 0, 0)
    event = @fake.create_event!(
      organizer_calendar: "org@l.test", starts_at: starts, ends_at: starts + 30.minutes,
      attendee_emails: [ @user.email ], summary: "HM"
    )
    @interview = Interview.create!(
      application: @application, stage_key: "onsite", interview_key: "hm",
      status: "scheduled", starts_at: starts, ends_at: starts + 30.minutes,
      calendar_event_id: event[:id], interviewer_user_ids: [ @user.id ]
    )
  end

  teardown do
    CalendarClient.backend = nil
    Current.reset
  end

  test "cancel removes calendar event and marks cancelled" do
    InterviewLifecycle.cancel!(interview: @interview, reason: "candidate_withdrew")
    assert_equal "cancelled", @interview.reload.status
    assert_nil @interview.calendar_event_id
    assert_empty @fake.events
    assert OutboxEvent.exists?(event_type: "interview.cancelled")
  end

  test "reschedule books new slot with live check" do
    new_start = Time.utc(2026, 11, 4, 14, 0, 0)
    InterviewLifecycle.reschedule!(
      interview: @interview,
      starts_at: new_start,
      ends_at: new_start + 30.minutes,
      organizer_calendar: "org@l.test",
      user_emails: @emails
    )
    assert_equal "scheduled", @interview.reload.status
    assert_equal new_start, @interview.starts_at
    assert_equal 1, @fake.events.size
    assert OutboxEvent.exists?(event_type: "interview.rescheduled")
  end
end
