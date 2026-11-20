# frozen_string_literal: true

class TimelineProjector
  def self.call(outbox_event:)
    return if outbox_event.blank?

    payload = outbox_event.payload
    person_id = payload["person_id"] || payload.dig("id")
    return if person_id.blank?

    event = TimelineEvent.find_or_create_by!(outbox_event_id: outbox_event.id) do |ev|
      ev.person_id = person_id
      ev.event_type = outbox_event.event_type
      ev.payload = payload
      ev.occurred_at = outbox_event.created_at
    end
    EngagementProjector.call(outbox_event: outbox_event)
    event
  end
end
