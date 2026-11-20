# frozen_string_literal: true

# Cancel and reschedule interviews; calendar updates go through CalendarClient.
class InterviewLifecycle
  def self.cancel!(interview:, reason: nil)
    new(interview).cancel!(reason: reason)
  end

  def self.reschedule!(interview:, starts_at:, ends_at:, interviewer_user_ids: nil, organizer_calendar:, user_emails:)
    new(interview).reschedule!(
      starts_at: starts_at, ends_at: ends_at,
      interviewer_user_ids: interviewer_user_ids,
      organizer_calendar: organizer_calendar,
      user_emails: user_emails
    )
  end

  def initialize(interview)
    @interview = interview
  end

  def cancel!(reason: nil)
    raise ArgumentError, "already_cancelled" if @interview.status == "cancelled"

    ActiveRecord::Base.transaction do
      previous = @interview.status
      if @interview.calendar_event_id.present?
        CalendarClient.delete_event!(event_id: @interview.calendar_event_id)
      end
      @interview.assign_attributes(
        status: "cancelled",
        calendar_event_id: nil
      )
      ChangeWriter.call(
        record: @interview,
        action: "interview.cancelled",
        event_type: "interview.cancelled",
        payload: { "reason" => reason }.compact,
        changes: { "status" => [ previous, "cancelled" ] }
      )
      @interview
    end
  end

  def reschedule!(starts_at:, ends_at:, interviewer_user_ids:, organizer_calendar:, user_emails:)
    raise ArgumentError, "not_scheduled" unless @interview.status == "scheduled"

    user_ids = interviewer_user_ids || Array(@interview.interviewer_user_ids)
    ActiveRecord::Base.transaction do
      if @interview.calendar_event_id.present?
        CalendarClient.delete_event!(event_id: @interview.calendar_event_id)
      end
      event = CalendarClient.backend.create_event_with_live_check!(
        organizer_calendar: organizer_calendar,
        starts_at: starts_at,
        ends_at: ends_at,
        interviewer_user_ids: user_ids,
        summary: "Reschedule #{@interview.interview_key}",
        user_emails: user_emails
      )
      previous_start = @interview.starts_at
      @interview.assign_attributes(
        starts_at: starts_at,
        ends_at: ends_at,
        interviewer_user_ids: user_ids,
        calendar_event_id: event[:id],
        status: "scheduled"
      )
      ChangeWriter.call(
        record: @interview,
        action: "interview.rescheduled",
        event_type: "interview.rescheduled",
        payload: { "from" => previous_start, "to" => starts_at },
        changes: { "starts_at" => [ previous_start, starts_at ] }
      )
      @interview
    end
  end
end
