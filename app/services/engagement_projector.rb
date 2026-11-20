# frozen_string_literal: true

# Keeps people.last_contacted_at / last_replied_at / last_activity_at / engagement_status current
# from the same outbox events the timeline reads. Runs inside TimelineProjector, so every path that
# writes a communication updates the person without knowing about it.
#
# Status moves forward on its own (not_contacted -> contacted -> replied). Interested, not_interested
# and do_not_contact are decisions: a later send or reply never overwrites them.
class EngagementProjector
  ORDER = %w[not_contacted contacted replied].freeze
  ACTIVITY_EVENTS = %w[
    communication.sent communication.received note.created task.completed application.created interview.scheduled
  ].freeze

  def self.call(outbox_event:)
    new(outbox_event).call
  end

  def initialize(outbox_event)
    @event = outbox_event
    @payload = outbox_event.payload || {}
  end

  def call
    return unless ACTIVITY_EVENTS.include?(@event.event_type)

    person = Person.unscoped.find_by(organization_id: @event.organization_id, id: @payload["person_id"])
    return if person.nil? || person.erased?

    at = @event.created_at || Time.current
    changes = { last_activity_at: [ person.last_activity_at, at ].compact.max }
    case @event.event_type
    when "communication.sent"
      changes[:last_contacted_at] = [ person.last_contacted_at, at ].compact.max
      changes[:engagement_status] = advance(person, "contacted")
    when "communication.received"
      if @payload["kind"].to_s == "reply"
        changes[:last_replied_at] = [ person.last_replied_at, at ].compact.max
        changes[:engagement_status] = advance(person, "replied")
      end
    end
    person.update_columns(changes.merge(updated_at: Time.current))
  end

  private

  def advance(person, target)
    current = person.engagement_status
    return current unless ORDER.include?(current)

    ORDER.index(target) > ORDER.index(current) ? target : current
  end
end
