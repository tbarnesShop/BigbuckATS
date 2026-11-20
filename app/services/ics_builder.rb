# frozen_string_literal: true

# Minimal .ics for no-calendar invites. Same UID + higher SEQUENCE updates clients.
class IcsBuilder
  def self.event(uid:, sequence:, starts_at:, ends_at:, summary:, description: nil, organizer_email:, attendee_emails: [])
    lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Big Buck//Scheduling//EN",
      "METHOD:REQUEST",
      "BEGIN:VEVENT",
      "UID:#{uid}",
      "SEQUENCE:#{sequence.to_i}",
      "DTSTAMP:#{fmt(Time.current)}",
      "DTSTART:#{fmt(starts_at)}",
      "DTEND:#{fmt(ends_at)}",
      "SUMMARY:#{escape(summary)}",
      "ORGANIZER:mailto:#{organizer_email}"
    ]
    lines << "DESCRIPTION:#{escape(description)}" if description.present?
    attendee_emails.each { |email| lines << "ATTENDEE:mailto:#{email}" }
    lines += %w[END:VEVENT END:VCALENDAR]
    lines.join("\r\n") + "\r\n"
  end

  def self.fmt(time)
    time.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  def self.escape(text)
    text.to_s.gsub("\\", "\\\\").gsub(";", "\\;").gsub(",", "\\,").gsub("\n", "\\n")
  end
end
