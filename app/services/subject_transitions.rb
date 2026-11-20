# frozen_string_literal: true

# One transition path for Application and ProjectMember.
class SubjectTransitions
  def self.move(subject:, to_stage_key:, reason: nil)
    new(subject).move(to_stage_key: to_stage_key, reason: reason)
  end

  def self.reject(subject:, reason:)
    new(subject).command("reject", status: "rejected", reason: reason)
  end

  def self.withdraw(subject:, reason: nil)
    new(subject).command("withdraw", status: "withdrawn", reason: reason)
  end

  def self.hire(subject:)
    new(subject).hire!
  end

  def initialize(subject)
    @subject = subject
    @pipeline = subject.pipeline
  end

  def move(to_stage_key:, reason: nil)
    raise ArgumentError, "unknown stage" unless @pipeline.stage_keys.include?(to_stage_key)
    raise ArgumentError, "not active" unless @subject.status == "active"
    raise ArgumentError, "use_hire_for_hired_stage" if @pipeline.stage(to_stage_key)&.dig("type") == "hired"

    from = @subject.current_stage_key
    StageGuards.check_exit!(subject: @subject, from_stage_key: from)
    StageGuards.check_entry!(subject: @subject, to_stage_key: to_stage_key)
    ActiveRecord::Base.transaction do
      @subject.update!(current_stage_key: to_stage_key, version: @subject.version + 1)
      record_transition(from, to_stage_key, "move", reason)
      ChangeWriter.call(
        record: @subject,
        action: "#{subject_name}.moved",
        event_type: "#{subject_name}.moved",
        payload: { "from" => from, "to" => to_stage_key },
        changes: { "current_stage_key" => [ from, to_stage_key ] }
      )
      @subject
    end
  end

  def hire!
    if @subject.is_a?(Application)
      org = Organization.find(Current.organization_id)
      if org.hire_requires_accepted_offer?
        accepted = Offer.exists?(application_id: @subject.id, status: "accepted")
        raise ArgumentError, "hire_requires_accepted_offer" unless accepted
      end
    end
    to = @subject.is_a?(Application) ? @pipeline.hired_stage_key! : nil
    command("hire", status: "hired", to_stage_key: to)
  end

  def command(name, status:, reason: nil, to_stage_key: nil)
    outcome = @subject.is_a?(Application) && DemoPolicy::APPLICATION_OUTCOMES.include?(name)
    if !outcome && DemoSandbox.for_organization(@subject.organization_id) && DemoPolicy.blocked?(action: name)
      raise Authenticator::Forbidden.new("demo_action_blocked", DemoPolicy::MESSAGE)
    end
    from = @subject.current_stage_key
    to = to_stage_key || from
    previous_status = @subject.status
    ActiveRecord::Base.transaction do
      @subject.update!(status: status, current_stage_key: to, version: @subject.version + 1)
      record_transition(from, to, name, reason)
      ChangeWriter.call(
        record: @subject,
        action: "#{subject_name}.#{name}",
        event_type: "#{subject_name}.#{name}",
        payload: { "reason" => reason }.compact,
        changes: { "status" => [ previous_status, status ], "current_stage_key" => (to == from ? nil : [ from, to ]) }.compact
      )
      @subject
    end.tap { stop_sequences_for(name) }
  end

  private

  def stop_sequences_for(command_name)
    return unless command_name == "hire" && @subject.is_a?(Application)

    EnrollmentStopper.call(person: @subject.person, reason: "hired")
  end

  def subject_name
    @subject.class.name.underscore
  end

  def record_transition(from, to, command, reason)
    StageTransition.create!(
      subject_type: @subject.class.name,
      subject_id: @subject.id,
      from_stage_key: from,
      to_stage_key: to,
      command: command,
      reason: reason,
      actor_id: Current.actor_id
    )
  end
end
