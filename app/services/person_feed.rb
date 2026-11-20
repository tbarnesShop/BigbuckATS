# frozen_string_literal: true

# One ordered stream for the person page: emails, notes, tasks, tags, stage moves, pool adds,
# applications and interviews, all read from timeline_events and hydrated with the record behind them.
class PersonFeed
  LIMIT = 100

  def self.call(person:, limit: LIMIT)
    new(person, limit).call
  end

  def initialize(person, limit)
    @person = person
    @limit = limit
  end

  def call
    events = TimelineEvent.where(person_id: @person.id).order(occurred_at: :desc, created_at: :desc).limit(@limit).to_a
    communications = hydrate(Communication, events, "communication.")
    notes = hydrate(PersonNote, events, "note.")
    tasks = hydrate(SourcingTask, events, "task.")
    users = User.where(id: [ notes.values.map(&:author_user_id), tasks.values.map(&:assignee_user_id) ].flatten.compact).index_by(&:id)

    events.filter_map { |event| item(event, communications, notes, tasks, users) }
  end

  private

  def hydrate(model, events, prefix)
    ids = events.select { |e| e.event_type.start_with?(prefix) }.filter_map { |e| e.payload["id"] || e.payload["note_id"] }
    model.where(id: ids).index_by(&:id)
  end

  def item(event, communications, notes, tasks, users)
    base = { "id" => event.id, "type" => event.event_type, "occurred_at" => event.occurred_at }
    payload = event.payload
    case event.event_type
    when "communication.sent", "communication.received"
      comm = communications[payload["id"]]
      return base.merge("kind" => "email", "direction" => payload["direction"], "subject" => payload["subject"]) unless comm

      base.merge("kind" => "email", "direction" => comm.direction, "subject" => comm.subject, "body" => comm.body,
        "thread_id" => comm.thread_id, "classification" => comm.classification, "communication_id" => comm.id,
        "rfc822_message_id" => comm.rfc822_message_id, "mailbox_id" => comm.mailbox_id)
    when "note.created", "note.updated"
      note = notes[payload["note_id"] || payload["id"]]
      return nil unless note

      base.merge("kind" => "note", "body" => note.body, "pinned" => note.pinned, "note_id" => note.id,
        "author" => users[note.author_user_id]&.name)
    when "task.created", "task.updated", "task.completed", "task.cancelled"
      task = tasks[payload["id"]]
      base.merge("kind" => "task", "title" => payload["title"], "task_type" => payload["task_type"],
        "status" => task&.status, "due_at" => task&.due_at, "task_id" => task&.id)
    when "person.tagged", "person.untagged"
      base.merge("kind" => "tag", "tag" => payload["tag"])
    else
      base.merge("kind" => "event")
    end
  end
end
