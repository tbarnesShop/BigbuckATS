# frozen_string_literal: true

# Opt-in sending window. Org setting `send_window`:
#   { "enabled" => true, "start_hour" => 9, "end_hour" => 17, "days" => [1,2,3,4,5], "timezone" => "America/New_York" }
# Off by default: sends go out immediately unless an org turns it on.
class SendWindow
  DEFAULT_DAYS = [ 1, 2, 3, 4, 5 ].freeze

  def self.next_allowed(organization, now = Time.current)
    new(organization.setting("send_window", {})).next_allowed(now)
  end

  def initialize(config)
    @config = (config || {}).deep_stringify_keys
  end

  def enabled?
    ActiveModel::Type::Boolean.new.cast(@config["enabled"])
  end

  # Earliest time >= now that falls inside the window.
  def next_allowed(now)
    return now unless enabled?

    zone = ActiveSupport::TimeZone[@config.fetch("timezone", "America/New_York")] || Time.find_zone!("America/New_York")
    start_hour = @config.fetch("start_hour", 9).to_i
    end_hour = @config.fetch("end_hour", 17).to_i
    days = Array(@config.fetch("days", DEFAULT_DAYS)).map(&:to_i)
    local = now.in_time_zone(zone)

    9.times do |offset|
      day = (local + offset.days).beginning_of_day
      next unless days.include?(day.wday)

      opens = day + start_hour.hours
      closes = day + end_hour.hours
      return now if offset.zero? && local >= opens && local < closes
      return opens.utc if opens > local
    end
    now
  end
end
