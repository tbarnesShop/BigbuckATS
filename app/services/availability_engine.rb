# frozen_string_literal: true

# Pure availability search on a 15-minute grid. Interviews placed in order
# same day with gaps up to max_gap_minutes; least-loaded interviewers first.
class AvailabilityEngine
  Slot = Struct.new(:starts_at, :ends_at, :blocks, keyword_init: true)
  Block = Struct.new(:interview_key, :starts_at, :ends_at, :user_ids, keyword_init: true)

  # Business hours in preferred_zone: when given, options inside them rank first. Without it, an interviewer
  # in another zone (Berlin) fills every option before the recruiter's working day starts (3 AM Eastern).
  PREFERRED_HOURS = (8...18)
  SCAN_FACTOR = 8

  def self.suggest(interviews:, profiles:, free_busy:, search_start:, search_end:, max_gap_minutes: 15, grid_minutes: 15, limit: 5, holiday_dates: [], preferred_zone: nil)
    new(
      interviews: interviews, profiles: profiles, free_busy: free_busy,
      search_start: search_start, search_end: search_end,
      max_gap_minutes: max_gap_minutes, grid_minutes: grid_minutes, limit: limit,
      holiday_dates: holiday_dates, preferred_zone: preferred_zone
    ).suggest
  end

  def initialize(interviews:, profiles:, free_busy:, search_start:, search_end:, max_gap_minutes:, grid_minutes:, limit:, holiday_dates: [], preferred_zone: nil)
    @preferred_zone = preferred_zone && ActiveSupport::TimeZone[preferred_zone]
    @interviews = interviews
    @profiles = profiles.index_by { |p| p[:user_id] }
    @free_busy = free_busy
    @search_start = search_start
    @search_end = search_end
    @max_gap_minutes = max_gap_minutes
    @grid_minutes = grid_minutes
    @limit = limit
    @holiday_dates = Array(holiday_dates).map { |d| d.to_date }.to_set
    @load = Hash.new(0)
  end

  def suggest
    options = []
    # With a preferred zone, gather more than needed so in-hours options can outrank earlier ones.
    wanted = @preferred_zone ? @limit * SCAN_FACTOR : @limit
    day = @search_start.to_date
    while day.to_time.utc < @search_end && options.size < wanted
      if @holiday_dates.include?(day)
        day += 1
        next
      end
      # Search the full UTC day when profiles define local working hours.
      # Candidate selection below intersects each interviewer's local windows.
      has_working_hours = @profiles.values.any? { |profile| profile[:working_hours].present? }
      day_start = Time.utc(day.year, day.month, day.day, has_working_hours ? 0 : 9)
      day_end = has_working_hours ? day_start + 1.day : Time.utc(day.year, day.month, day.day, 17)
      day_start = [ day_start, @search_start ].max
      day_end = [ day_end, @search_end ].min
      t = align(day_start)
      while t < day_end && options.size < wanted
        option = try_from(t, day_end)
        if option
          options << option
          option.blocks.each { |b| b.user_ids.each { |u| @load[u] += 1 } }
          t = option.ends_at + @grid_minutes.minutes
        else
          t += @grid_minutes.minutes
        end
      end
      day += 1
    end
    options.sort_by { |o| [ outside_preferred_hours?(o) ? 1 : 0, load_score(o), o.starts_at ] }.first(@limit)
  end

  def outside_preferred_hours?(option)
    return false unless @preferred_zone

    from = option.starts_at.in_time_zone(@preferred_zone)
    to = option.ends_at.in_time_zone(@preferred_zone)
    !(PREFERRED_HOURS.cover?(from.hour) && from.to_date == to.to_date &&
      (to.hour < PREFERRED_HOURS.end || (to.hour == PREFERRED_HOURS.end && to.min.zero?)))
  end

  private

  def try_from(start_at, day_end)
    blocks = []
    t = start_at
    @interviews.each do |interview|
      duration = interview.fetch(:duration_minutes)
      needed = interview.fetch(:count, 1)
      candidates = interview.fetch(:candidate_user_ids).reject { |uid| @profiles.dig(uid, :paused) }
      placed = nil
      while t + duration.minutes <= day_end
        chosen = pick_free(candidates, t, t + duration.minutes, needed)
        if chosen
          blocks << Block.new(
            interview_key: interview[:key],
            starts_at: t,
            ends_at: t + duration.minutes,
            user_ids: chosen
          )
          placed = true
          t = t + duration.minutes + @max_gap_minutes.minutes
          break
        end
        t += @grid_minutes.minutes
      end
      return nil unless placed
    end
    Slot.new(starts_at: blocks.first.starts_at, ends_at: blocks.last.ends_at, blocks: blocks)
  end

  def pick_free(candidates, from, to, needed)
    free = candidates.select { |uid| free?(uid, from, to) }.sort_by { |uid| [ @load[uid], uid ] }
    return nil if free.size < needed

    free.first(needed)
  end

  def free?(uid, from, to)
    return false unless @profiles[uid]
    return false if @profiles[uid][:paused]

    profile = @profiles[uid]
    if profile[:working_hours].present?
      zone = ActiveSupport::TimeZone[profile[:time_zone].presence || "UTC"]
      return false unless zone
      local_from = from.in_time_zone(zone)
      local_to = to.in_time_zone(zone)
      return false unless local_from.to_date == local_to.to_date
      windows = Array(profile[:working_hours][local_from.strftime("%a").downcase])
      inside = windows.any? do |first, last|
        hours, minutes = first.split(":").map(&:to_i)
        finish_hours, finish_minutes = last.split(":").map(&:to_i)
        window_start = zone.local(local_from.year, local_from.month, local_from.day, hours, minutes)
        window_end = zone.local(local_from.year, local_from.month, local_from.day, finish_hours, finish_minutes)
        from >= window_start && to <= window_end
      end
      return false unless inside
    end
    busy = Array(@free_busy[uid])
    busy.none? { |a, b| a < to && b > from }
  end

  def align(time)
    seconds = @grid_minutes * 60
    Time.at((time.to_f / seconds).ceil * seconds).utc
  end

  def load_score(option)
    option.blocks.sum { |b| b.user_ids.sum { |u| @load[u] } }
  end
end
