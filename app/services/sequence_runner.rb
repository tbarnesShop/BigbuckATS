# frozen_string_literal: true

# Runs sequences. Email steps send; wait steps schedule next_run_at;
# task steps open a sourcing task for the recruiter and pause until completed
# (or auto-advance when no assignee workflow is configured — we create the task
# and continue so enrollments do not stall forever).
#
# Step specs: { "type" => "email", "template_key" => "..." }
#             { "type" => "wait", "days" => 3 }   (or "hours" / "minutes"; default 1 day)
#             { "type" => "task", "title" => "Call candidate" }
class SequenceRunner
  LEASE = 10.minutes

  def self.enroll!(sequence:, person:, mailbox:, merge_fields: nil)
    OutreachPolicy.check!(person: person)
    ConsentGate.check!(person: person, action: "sequence.enroll")

    enrollment = SequenceEnrollment.create!(
      sequence: sequence,
      person: person,
      mailbox: mailbox,
      step_index: 0,
      status: "active",
      merge_fields: merge_fields.presence
    )
    advance!(enrollment)
    enrollment
  rescue OutreachPolicy::Blocked => e
    raise ArgumentError, e.code
  end

  def self.advance!(enrollment)
    loop do
      return unless enrollment.active?

      if enrollment.person.do_not_contact
        enrollment.stop!("do_not_contact")
        return
      end

      step = enrollment.sequence.steps[enrollment.step_index]
      unless step
        enrollment.update!(next_run_at: nil) if enrollment.next_run_at
        return
      end

      step = step.stringify_keys
      case step["type"]
      when "email"
        send_email!(enrollment, step)
        enrollment.update!(step_index: enrollment.step_index + 1, next_run_at: nil)
        enrollment.reload
      when "wait"
        enrollment.update!(step_index: enrollment.step_index + 1, next_run_at: Time.current + wait_for(step))
        return
      when "task"
        task = create_task!(enrollment, step)
        enrollment.update!(step_index: enrollment.step_index + 1, next_run_at: nil)
        # A task that pauses the sequence holds it until completed; SourcingTask#complete! resumes it.
        return if task.pauses_enrollment

        enrollment.reload
      else
        enrollment.update!(step_index: enrollment.step_index + 1)
      end
    end
  end

  def self.tick!(now: Time.current, limit: 200)
    claimed = SequenceEnrollment.transaction do
      rows = SequenceEnrollment.unscoped.where(status: "active").where("next_run_at <= ?", now)
                               .order(:next_run_at).limit(limit).lock("FOR UPDATE SKIP LOCKED").to_a
      SequenceEnrollment.unscoped.where(id: rows.map(&:id)).update_all(next_run_at: now + LEASE, updated_at: now)
      rows
    end

    claimed.each do |row|
      Current.set(organization_id: row.organization_id, actor_type: "system", source_surface: "automation") do
        advance!(SequenceEnrollment.find(row.id))
      rescue StandardError => e
        Rails.logger.error({ event: "sequence.step_failed", enrollment_id: row.id, error: e.class.name, message: e.message }.to_json)
      end
    end
    claimed.size
  end

  def self.wait_for(step)
    if step["minutes"] then step["minutes"].to_i.minutes
    elsif step["hours"] then step["hours"].to_i.hours
    else (step["days"] || 1).to_i.days
    end
  end

  def self.send_email!(enrollment, step)
    template = MessageTemplate.find_by!(key: step.fetch("template_key"))
    queued = SendQueue.enqueue!(enrollment: enrollment, template: template, step_id: step["id"], send_as_user_id: step["send_as_user_id"])
    SendQueue.process!(queued)
  end

  def self.create_task!(enrollment, step)
    task = SourcingTask.create!(
      person: enrollment.person,
      sequence_enrollment: enrollment,
      title: step["title"].presence || "Sequence task",
      task_type: SourcingTask::TYPES.include?(step["task_type"]) ? step["task_type"] : "other",
      assignee_user_id: step["assignee_user_id"].presence || enrollment.mailbox&.user_id,
      status: "open",
      pauses_enrollment: ActiveModel::Type::Boolean.new.cast(step.fetch("pause_until_done", true)),
      due_at: step["due_in_days"] ? Time.current + step["due_in_days"].to_i.days : nil
    )
    emit_task_created(task)
    task
  end

  def self.emit_task_created(task)
    outcome = ChangeWriter.call(
      record: task, action: "task.created", event_type: "task.created",
      payload: { "person_id" => task.person_id, "title" => task.title, "task_type" => task.task_type }
    )
    TimelineProjector.call(outbox_event: outcome.outbox_event)
  end

  private_class_method :send_email!, :create_task!, :wait_for, :emit_task_created
end
