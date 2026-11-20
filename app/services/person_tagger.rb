# frozen_string_literal: true

# Add or remove a tag on a person, once, with a timeline event. Idempotent both ways.
class PersonTagger
  def self.add!(person:, tag:)
    row = PersonTag.find_by(person_id: person.id, tag_id: tag.id)
    return row if row

    row = PersonTag.new(person: person, tag: tag, added_by_user_id: Current.actor_id.presence)
    event(row, "person.tagged", person, tag)
    row
  end

  def self.remove!(person:, tag:)
    row = PersonTag.find_by(person_id: person.id, tag_id: tag.id)
    return nil unless row

    ActiveRecord::Base.transaction do
      row.destroy!
      outcome = ChangeWriter.call(
        record: person, action: "person.untagged", event_type: "person.untagged",
        payload: { "person_id" => person.id, "tag" => tag.name }, changes: { "tags" => [ tag.name, nil ] }
      )
      TimelineProjector.call(outbox_event: outcome.outbox_event)
    end
    row
  end

  def self.event(row, type, person, tag)
    ActiveRecord::Base.transaction do
      row.save!
      outcome = ChangeWriter.call(
        record: person, action: type, event_type: type,
        payload: { "person_id" => person.id, "tag" => tag.name }, changes: { "tags" => [ nil, tag.name ] }
      )
      TimelineProjector.call(outbox_event: outcome.outbox_event)
    end
  end
  private_class_method :event
end
