# frozen_string_literal: true

# Suggests a panel, then books with a live free/busy re-check; on stale slot
# refuses and returns the next-best suggestion.
class PanelBooking
  Result = Struct.new(:booked, :interviews, :refused_reason, :next_option, keyword_init: true)
  # The zone recruiters see times in (web/app/data/labels.ts). Suggestions inside its business hours rank first.
  DISPLAY_ZONE = "America/New_York"

  def self.suggest_and_book!(application:, interview_defs:, profiles:, organizer_calendar:, user_emails:, search_start:, search_end:)
    new(
      application: application, interview_defs: interview_defs, profiles: profiles,
      organizer_calendar: organizer_calendar, user_emails: user_emails,
      search_start: search_start, search_end: search_end
    ).suggest_and_book!
  end

  def initialize(application:, interview_defs:, profiles:, organizer_calendar:, user_emails:, search_start:, search_end:)
    @application = application
    @interview_defs = interview_defs
    saved = InterviewerProfile.where(user_id: profiles.map { |profile| profile[:user_id] }).index_by(&:user_id)
    @profiles = profiles.map do |profile|
      record = saved[profile[:user_id]]
      record ? profile.merge(paused: record.paused, time_zone: record.time_zone, working_hours: record.working_hours, buffer_minutes: record.buffer_minutes) : profile
    end
    @organizer_calendar = organizer_calendar
    @user_emails = user_emails
    @search_start = search_start
    @search_end = search_end
  end

  def suggest_and_book!
    options = suggest
    raise ArgumentError, "no_options" if options.empty?

    attempt_book(options)
  end

  # Preview never creates a calendar event or an interview record.
  def suggest
    user_ids = @interview_defs.flat_map { |i| i[:candidate_user_ids] }.uniq
    free_busy = CalendarClient.free_busy(user_ids: user_ids, time_min: @search_start, time_max: @search_end)
    # Include local bookings too: demo free/busy intentionally makes no external calls.
    Interview.where(status: "scheduled").where("starts_at < ? AND ends_at > ?", @search_end, @search_start).find_each do |interview|
      (interview.application_id == @application.id ? user_ids : interview.interviewer_user_ids & user_ids).each do |user_id|
        buffer = @profiles.find { |profile| profile[:user_id] == user_id }&.fetch(:buffer_minutes, 0).to_i.minutes
        (free_busy[user_id] ||= []) << [ interview.starts_at - buffer, interview.ends_at + buffer ]
      end
    end
    AvailabilityEngine.suggest(
      interviews: @interview_defs,
      profiles: @profiles,
      free_busy: free_busy,
      search_start: @search_start,
      search_end: @search_end,
      preferred_zone: DISPLAY_ZONE
    )
  end

  # Only book the reviewed option. Do not silently choose an alternative if
  # availability changes between preview and confirmation.
  def book_selected!(selected)
    @application.with_lock do
      raise ArgumentError, "application_not_active" unless @application.status == "active"
      @search_start = Time.iso8601(selected.fetch("starts_at"))
      @search_end = Time.iso8601(selected.fetch("ends_at"))
      @interview_defs = @interview_defs.map.with_index do |definition, index|
        # Recheck the reviewed attendees rather than rerunning pool selection,
        # whose load balancing may choose someone else for a later option.
        definition.merge(candidate_user_ids: selected.fetch("blocks").fetch(index).fetch("user_ids"))
      end
      option = suggest.find { |candidate| self.class.serialize_option(candidate) == selected }
      raise ArgumentError, "slot_unavailable" unless option

      Result.new(booked: true, interviews: book_option!(option))
    end
  rescue CalendarClient::StaleSlot
    raise ArgumentError, "slot_unavailable"
  end

  def self.serialize_option(option)
    {
      "starts_at" => option.starts_at.iso8601,
      "ends_at" => option.ends_at.iso8601,
      "blocks" => option.blocks.map do |block|
        { "interview_key" => block.interview_key, "starts_at" => block.starts_at.iso8601,
          "ends_at" => block.ends_at.iso8601, "user_ids" => block.user_ids.sort }
      end
    }
  end

  private

  def attempt_book(options)
    option = options.first
    rest = options.drop(1)
    begin
      interviews = book_option!(option)
      Result.new(booked: true, interviews: interviews)
    rescue CalendarClient::StaleSlot => e
      return Result.new(booked: false, refused_reason: e.message, next_option: rest.first) if rest.empty?

      # Re-book next best with another live check
      attempt_book(rest)
    end
  end

  def book_option!(option)
    ActiveRecord::Base.transaction do
      option.blocks.map do |block|
        event = CalendarClient.create_event_with_live_check!(
          organizer_calendar: @organizer_calendar,
          starts_at: block.starts_at,
          ends_at: block.ends_at,
          interviewer_user_ids: block.user_ids,
          summary: "#{@application.job.title} — #{block.interview_key}",
          user_emails: @user_emails
        )
        Interview.create!(
          application: @application,
          stage_key: @application.current_stage_key,
          interview_key: block.interview_key,
          status: "scheduled",
          starts_at: block.starts_at,
          ends_at: block.ends_at,
          calendar_event_id: event[:id],
          interviewer_user_ids: block.user_ids
        )
      end
    end
  end
end
