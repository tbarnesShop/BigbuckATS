# frozen_string_literal: true

# Create a self-schedule link and redeem it to book a panel.
class SelfSchedule
  def self.create_link!(application:, interview_keys:, kind: "self_schedule", expires_at: 7.days.from_now)
    link = SchedulingLink.create!(
      application: application,
      kind: kind,
      interview_keys: Array(interview_keys),
      expires_at: expires_at
    )
    { link: link, token: SchedulingLinkToken.issue(link) }
  end

  def self.book!(token:, interview_defs:, profiles:, organizer_calendar:, user_emails:, search_start:, search_end:)
    link = SchedulingLinkToken.verify(token)
    raise ArgumentError, "wrong_kind" unless link.kind == "self_schedule"

    Current.organization_id ||= link.organization_id
    application = Application.find(link.application_id)

    result = nil
    ActiveRecord::Base.transaction do
      # Atomic single-use: only the first redeemer wins.
      updated = SchedulingLink.where(id: link.id, used_at: nil, revoked_at: nil)
                              .where("expires_at > ?", Time.current)
                              .update_all(used_at: Time.current, updated_at: Time.current)
      raise ArgumentError, "unusable_link" if updated != 1

      result = PanelBooking.suggest_and_book!(
        application: application,
        interview_defs: interview_defs,
        profiles: profiles,
        organizer_calendar: organizer_calendar,
        user_emails: user_emails,
        search_start: search_start,
        search_end: search_end
      )
      raise ArgumentError, "booking_failed:#{result.refused_reason}" unless result.booked
    end
    result
  end
end
