# frozen_string_literal: true

module V1
  class SequencesController < ApplicationController
    include PersonScoped

    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_sequence", title: error.message)
    end
    rescue_from ConsentGate::Blocked do |error|
      render_problem(status: :forbidden, code: "consent_blocked", title: error.message)
    end

    def index
      rows = Sequence.order(:created_at).limit(100)
      rows = rows.where(is_template: true) if ActiveModel::Type::Boolean.new.cast(params[:templates])
      rows = rows.where(shared: true) if ActiveModel::Type::Boolean.new.cast(params[:shared])
      render json: { data: rows.map { |s| serialize(s) } }
    end

    def show
      render json: serialize(Sequence.find(params[:id]))
    end

    def create
      with_idempotency do
        sequence = Sequence.create!(
          key: sequence_params.require(:key),
          name: sequence_params.require(:name),
          steps: SequenceSteps.normalize(Array(sequence_params[:steps]).presence || default_steps),
          description: sequence_params[:description],
          owner_user_id: sequence_params[:owner_user_id].presence || Current.actor_id,
          status: sequence_params[:status].presence || "active",
          shared: sequence_params.key?(:shared) ? ActiveModel::Type::Boolean.new.cast(sequence_params[:shared]) : true,
          is_template: ActiveModel::Type::Boolean.new.cast(sequence_params[:is_template]) || false
        )
        ChangeWriter.call(
          record: sequence, action: "sequence.created", event_type: "sequence.created",
          payload: { "key" => sequence.key }
        )
        render json: serialize(sequence), status: :created
      end
    end

    def update
      with_idempotency do
        sequence = Sequence.find(params[:id])
        attrs = sequence_params.to_h.slice("name", "description", "owner_user_id", "status", "shared")
        attrs["steps"] = SequenceSteps.normalize(sequence_params[:steps]) if params.dig(:sequence, :steps)
        sequence.update!(attrs)
        ChangeWriter.call(
          record: sequence, action: "sequence.updated", event_type: "sequence.updated",
          payload: { "key" => sequence.key }, changes: sequence.saved_changes.slice(*attrs.keys)
        )
        render json: serialize(sequence)
      end
    end

    # Renders every email step for one person, as it would go out from the chosen mailbox.
    def preview
      sequence = Sequence.find(params[:id])
      person = visible_person!(params.require(:person_id))
      mailbox = resolve_mailbox!(params[:mailbox_id])
      tokens = MessageTokens.for(person: person, sender: mailbox.user, sender_email: mailbox.email)
      steps = Array(sequence.steps).each_with_index.map do |raw, index|
        step = raw.stringify_keys
        row = { "index" => index, "id" => step["id"], "type" => step["type"] }
        case step["type"]
        when "email"
          template = MessageTemplate.find_by(key: step["template_key"])
          row.merge!("template_key" => step["template_key"], "subject" => template && MessageRenderer.render(template.subject, tokens, escape: false),
                     "body" => template && MessageRenderer.render(template.body, tokens, escape: false), "missing_template" => template.nil?)
        when "wait" then row.merge!(step.slice("days", "hours", "minutes"))
        when "task" then row.merge!(step.slice("title", "task_type", "pause_until_done"))
        end
        row
      end
      render json: { "sequence_id" => sequence.id, "person_id" => person.id, "steps" => steps }
    rescue MessageRenderer::MissingToken => e
      render_problem(status: :unprocessable_entity, code: "unknown_token", title: "Unknown merge field: #{e.message}")
    end

    # Per-step outcomes: how many sends were queued, sent, deferred or cancelled, and how many
    # enrollments ended in a reply after that step's message.
    def stats
      sequence = Sequence.find(params[:id])
      enrollment_scope = SequenceEnrollment.where(sequence_id: sequence.id)
      messages = ScheduledMessage.where(sequence_enrollment_id: enrollment_scope.select(:id))
      by_step = messages.group(:sequence_step_id, :status).count
      replied = enrollment_scope.where(stop_reason: "reply").pluck(:id)
      reply_steps = messages.where(sequence_enrollment_id: replied, status: "sent").order(:sent_at)
                            .pluck(:sequence_enrollment_id, :sequence_step_id).to_h
      replies = reply_steps.values.tally
      steps = Array(sequence.steps).map do |raw|
        id = raw["id"]
        counts = ScheduledMessage::STATUSES.index_with { |st| by_step[[ id, st ]].to_i }
        { "id" => id, "type" => raw["type"], "template_key" => raw["template_key"], "title" => raw["title"],
          "messages" => counts, "replies" => replies[id].to_i }
      end
      render json: {
        "sequence_id" => sequence.id,
        "enrolled" => enrollment_scope.count,
        "active" => enrollment_scope.where(status: "active").count,
        "stopped" => enrollment_scope.where(status: "stopped").group(:stop_reason).count,
        "steps" => steps
      }
    end

    def enrollments
      sequence = Sequence.find(params[:id])
      rows = SequenceEnrollment.includes(:person, :mailbox, :sequence)
                               .where(sequence_id: sequence.id)
                               .order(:created_at)
      render json: { data: rows.map { |e| serialize_enrollment(e) } }
    end

    def create_enrollment
      with_idempotency do
        sequence = Sequence.find(params[:id])
        person = ResourceVisibility.people.find(enrollment_params.require(:person_id))
        mailbox = resolve_mailbox!(enrollment_params[:mailbox_id])
        enrollment = SequenceRunner.enroll!(sequence: sequence, person: person, mailbox: mailbox)
        render json: serialize_enrollment(enrollment.reload), status: :created
      end
    end

    # Dry run: who would be enrolled and why anyone would be skipped. Writes nothing.
    def enrollment_plan
      sequence = Sequence.find(params[:id])
      mailbox = resolve_mailbox!(params[:mailbox_id])
      plan = EnrollmentPlanner.plan(people: selected_people, exclude_person_ids: params[:exclude_person_ids])
      render json: {
        "sequence_id" => sequence.id, "mailbox_id" => mailbox.id, "counts" => plan.counts,
        "will_enroll" => plan.eligible.map { |p| plan_person(p) },
        "skipped" => plan.skipped.map { |s| plan_person(s[:person]).merge("reason" => s[:reason]) },
        "first_send_at" => SendWindow.next_allowed(Organization.find(Current.organization_id), Time.current)
      }
    end

    # Commits a reviewed plan. Re-plans first, so people who became ineligible are skipped.
    def enroll_planned
      with_idempotency do
        sequence = Sequence.find(params[:id])
        mailbox = resolve_mailbox!(params[:mailbox_id])
        plan = EnrollmentPlanner.plan(people: selected_people, exclude_person_ids: params[:exclude_person_ids])
        results = plan.eligible.map do |person|
          enrollment = SequenceRunner.enroll!(sequence: sequence, person: person, mailbox: mailbox)
          { "person_id" => person.id, "ok" => true, "enrollment_id" => enrollment.id }
        rescue StandardError => e
          { "person_id" => person.id, "ok" => false, "error" => e.message }
        end
        render json: {
          "sequence_id" => sequence.id, "enrolled" => results.count { |r| r["ok"] },
          "failed" => results.count { |r| !r["ok"] }, "skipped" => plan.counts["skipped"], "results" => results
        }
      end
    end

    def bulk_enroll
      with_idempotency do
        sequence = Sequence.find(params[:id])
        mailbox = resolve_mailbox!(params[:mailbox_id])
        person_ids = Array(params[:person_ids]).uniq
        raise ArgumentError, "person_ids_required" if person_ids.empty?
        raise ArgumentError, "too_many_people" if person_ids.size > 100

        results = person_ids.map do |pid|
          person = ResourceVisibility.people.find(pid)
          enrollment = SequenceRunner.enroll!(sequence: sequence, person: person, mailbox: mailbox)
          { "person_id" => pid, "ok" => true, "enrollment_id" => enrollment.id }
        rescue StandardError => e
          { "person_id" => pid, "ok" => false, "error" => e.message }
        end
        render json: { "sequence_id" => sequence.id, "results" => results }
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def selected_people
      if params[:person_ids].present?
        ResourceVisibility.people.where(id: Array(params[:person_ids]).first(EnrollmentPlanner::MAX_PEOPLE)).order(:created_at)
      elsif params[:project_id].present?
        ids = ResourceVisibility.members.where(project_id: params[:project_id], status: "active").limit(EnrollmentPlanner::MAX_PEOPLE).pluck(:person_id)
        ResourceVisibility.people.where(id: ids).order(:created_at)
      elsif params[:saved_search_id].present?
        PersonSearch.call(viewer: viewer, filters: SavedSearch.find(params[:saved_search_id]).filters.to_h, limit: EnrollmentPlanner::MAX_PEOPLE)
      elsif params[:filters].present?
        PersonSearch.call(viewer: viewer, filters: PersonSearch.permitted_filters(params[:filters]), limit: EnrollmentPlanner::MAX_PEOPLE)
      else
        raise ArgumentError, "selection_required"
      end
    end

    def plan_person(person)
      { "person_id" => person.id, "display_name" => person.display_name, "primary_email" => person.primary_email,
        "current_title" => person.current_title, "last_contacted_at" => person.last_contacted_at }
    end

    def resolve_mailbox!(mailbox_id)
      if mailbox_id.present?
        Mailbox.find(mailbox_id)
      else
        Mailbox.order(:created_at).first || raise(ArgumentError, "mailbox_required")
      end
    end

    def sequence_params
      params.require(:sequence).permit(
        :key, :name, :status, :shared, :is_template, :description, :owner_user_id,
        steps: [ :id, :type, :template_key, :channel, :send_as_user_id, :days, :hours, :minutes, :title, :assignee_user_id, :due_in_days, :task_type, :pause_until_done ]
      )
    end

    def enrollment_params
      params.require(:enrollment).permit(:person_id, :mailbox_id)
    end

    def default_steps
      key = MessageTemplate.active.order(:created_at).pick(:key)
      key ? [ { "type" => "email", "template_key" => key } ] : []
    end

    def serialize(sequence)
      sequence.as_json(only: %i[id organization_id key name description owner_user_id status shared is_template created_at updated_at])
              .merge(
                "steps" => Array(sequence.steps),
                "enrollment_count" => SequenceEnrollment.where(sequence_id: sequence.id).count
              )
    end

    def serialize_enrollment(enrollment)
      enrollment.as_json(
        only: %i[id organization_id sequence_id person_id mailbox_id step_index status stop_reason created_at updated_at]
      ).merge(
        "person" => ResourceSummary.person(enrollment.person, fields: %i[id display_name primary_email]),
        "sequence" => enrollment.sequence&.as_json(only: %i[id key name]),
        "mailbox" => enrollment.mailbox&.as_json(only: %i[id email kind])
      )
    end
  end
end
