# frozen_string_literal: true

# When an interviewer declines, swap in the least-loaded free pool member
# for the same slot when on_decline is replace_from_pool.
class DeclineReplacement
  Result = Struct.new(:replaced, :interview, :reason, keyword_init: true)

  def self.call(interview:, declined_user_id:, pool_user_ids:, profiles:, user_emails:, organizer_calendar:)
    new(
      interview: interview, declined_user_id: declined_user_id,
      pool_user_ids: pool_user_ids, profiles: profiles,
      user_emails: user_emails, organizer_calendar: organizer_calendar
    ).call
  end

  def initialize(interview:, declined_user_id:, pool_user_ids:, profiles:, user_emails:, organizer_calendar:)
    @interview = interview
    @declined_user_id = declined_user_id
    @pool_user_ids = Array(pool_user_ids)
    @profiles = profiles
    @user_emails = user_emails
    @organizer_calendar = organizer_calendar
  end

  def call
    return Result.new(replaced: false, interview: @interview, reason: "on_decline_not_replace") unless @interview.on_decline == "replace_from_pool"
    return Result.new(replaced: false, interview: @interview, reason: "not_scheduled") unless @interview.status == "scheduled"

    current = Array(@interview.interviewer_user_ids)
    return Result.new(replaced: false, interview: @interview, reason: "declined_not_assigned") unless current.include?(@declined_user_id)

    candidates = @pool_user_ids - current
    free_busy = CalendarClient.free_busy(
      user_ids: candidates,
      time_min: @interview.starts_at,
      time_max: @interview.ends_at
    )
    load = recent_load(candidates)
    replacement = candidates
                  .reject { |uid| @profiles.find { |p| p[:user_id] == uid }&.dig(:paused) }
                  .select { |uid| free_busy[uid].to_a.none? { |a, b| a < @interview.ends_at && b > @interview.starts_at } }
                  .min_by { |uid| [ load[uid], uid ] }

    unless replacement
      @interview.update!(status: "needs_attention", needs_attention_reason: "decline_no_replacement")
      return Result.new(replaced: false, interview: @interview, reason: "no_replacement")
    end

    new_ids = current.map { |id| id == @declined_user_id ? replacement : id }
    ActiveRecord::Base.transaction do
      CalendarClient.delete_event!(event_id: @interview.calendar_event_id) if @interview.calendar_event_id.present?
      event = CalendarClient.backend.create_event_with_live_check!(
        organizer_calendar: @organizer_calendar,
        starts_at: @interview.starts_at,
        ends_at: @interview.ends_at,
        interviewer_user_ids: new_ids,
        summary: "Interview #{@interview.interview_key}",
        user_emails: @user_emails
      )
      @interview.assign_attributes(
        interviewer_user_ids: new_ids,
        calendar_event_id: event[:id],
        status: "scheduled",
        needs_attention_reason: nil
      )
      ChangeWriter.call(
        record: @interview,
        action: "interview.interviewer_replaced",
        event_type: "interview.interviewer_replaced",
        payload: { "declined" => @declined_user_id, "replacement" => replacement },
        changes: { "interviewer_user_ids" => [ current, new_ids ] }
      )
    end
    Result.new(replaced: true, interview: @interview)
  end

  private

  def recent_load(user_ids)
    window_start = 7.days.ago
    counts = Hash.new(0)
    Interview.where(status: %w[scheduled completed]).where("starts_at >= ?", window_start).find_each do |i|
      Array(i.interviewer_user_ids).each { |uid| counts[uid] += 1 if user_ids.include?(uid) }
    end
    counts
  end
end
