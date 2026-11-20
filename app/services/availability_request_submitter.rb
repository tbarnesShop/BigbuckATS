# frozen_string_literal: true

# Candidate submits availability windows; optionally auto-books the best option.
class AvailabilityRequestSubmitter
  Result = Struct.new(:request, :booking, keyword_init: true)

  def self.call(token:, windows:, candidate_time_zone: nil, auto_book: false, interview_defs: nil, profiles: nil, organizer_calendar: nil, user_emails: nil)
    new(
      token: token, windows: windows, candidate_time_zone: candidate_time_zone,
      auto_book: auto_book, interview_defs: interview_defs, profiles: profiles,
      organizer_calendar: organizer_calendar, user_emails: user_emails
    ).call
  end

  def initialize(token:, windows:, candidate_time_zone:, auto_book:, interview_defs:, profiles:, organizer_calendar:, user_emails:)
    @token = token
    @windows = Array(windows)
    @candidate_time_zone = candidate_time_zone
    @auto_book = auto_book
    @interview_defs = interview_defs
    @profiles = profiles
    @organizer_calendar = organizer_calendar
    @user_emails = user_emails
  end

  def call
    link = SchedulingLinkToken.verify(@token)
    raise ArgumentError, "wrong_kind" unless link.kind == "availability"
    raise ArgumentError, "empty_windows" if @windows.empty?

    Current.organization_id ||= link.organization_id
    booking = nil
    request = nil
    ActiveRecord::Base.transaction do
      updated = SchedulingLink.where(id: link.id, used_at: nil, revoked_at: nil)
                              .where("expires_at > ?", Time.current)
                              .update_all(used_at: Time.current, updated_at: Time.current)
      raise ArgumentError, "unusable_link" if updated != 1

      request = AvailabilityRequest.create!(
        scheduling_link: link,
        candidate_time_zone: @candidate_time_zone,
        windows: @windows,
        auto_book: @auto_book,
        submitted_at: Time.current
      )

      if @auto_book && @interview_defs
        search_start, search_end = window_bounds(@windows)
        booking = PanelBooking.suggest_and_book!(
          application: Application.find(link.application_id),
          interview_defs: @interview_defs,
          profiles: @profiles,
          organizer_calendar: @organizer_calendar,
          user_emails: @user_emails,
          search_start: search_start,
          search_end: search_end
        )
        raise ArgumentError, "booking_failed" unless booking.booked
      end
    end
    Result.new(request: request, booking: booking)
  end

  private

  def window_bounds(windows)
    starts = windows.map { |w| Time.zone.parse(w.fetch("start").to_s) }
    ends = windows.map { |w| Time.zone.parse(w.fetch("end").to_s) }
    [ starts.min, ends.max ]
  end
end
