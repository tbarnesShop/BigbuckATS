# frozen_string_literal: true

module V1
  # Follow-ups. GET /v1/tasks?assignee=me&due=today is the Today panel.
  class TasksController < ApplicationController
    include PersonScoped

    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_task", title: error.message)
    end

    def index
      rows = SourcingTask.where(person_id: ResourceVisibility.people.select(:id)).includes(:person)
      rows = rows.where(status: params[:status].presence || "open") unless params[:status] == "all"
      rows = rows.where(person_id: params[:person_id]) if params[:person_id].present?
      rows = rows.where(task_type: params[:task_type]) if params[:task_type].present?
      assignee = params[:assignee] == "me" ? Current.actor_id : params[:assignee]
      rows = rows.where(assignee_user_id: assignee) if assignee.present?
      case params[:due]
      when "overdue" then rows = rows.where("due_at < ?", Time.current)
      when "today" then rows = rows.where("due_at <= ?", Time.zone.now.end_of_day)
      when "upcoming" then rows = rows.where("due_at > ?", Time.zone.now.end_of_day)
      when "none" then rows = rows.where(due_at: nil)
      end
      rows = rows.order(Arel.sql("due_at IS NULL, due_at ASC"), :created_at).limit(200)
      render json: { data: rows.map { |t| serialize(t) } }
    end

    def create
      with_idempotency do
        person = visible_person!(task_params.require(:person_id))
        task = SourcingTask.new(
          person: person, title: task_params[:title].to_s.strip, description: task_params[:description],
          task_type: task_params[:task_type].presence || "other", due_at: task_params[:due_at].presence,
          assignee_user_id: task_params[:assignee_user_id].presence || (Current.agent_id.present? ? nil : Current.actor_id),
          assignee_agent_id: task_params[:assignee_agent_id].presence,
          application_id: task_params[:application_id].presence, project_member_id: task_params[:project_member_id].presence,
          created_by_user_id: Current.actor_id.presence, status: "open"
        )
        write(task, "task.created")
        render json: serialize(task), status: :created
      end
    end

    def update
      with_idempotency do
        task = SourcingTask.find(params[:id])
        visible_person!(task.person_id)
        raise ArgumentError, "task_is_closed" unless task.open?

        %i[title description task_type due_at assignee_user_id assignee_agent_id].each do |field|
          task[field] = task_params[field].presence if task_params.key?(field)
        end
        write(task, "task.updated")
        render json: serialize(task)
      end
    end

    def complete
      with_idempotency do
        task = SourcingTask.find(params[:id])
        visible_person!(task.person_id)
        raise ArgumentError, "task_is_closed" unless task.open?

        task.complete!
        emit(task, "task.completed")
        render json: serialize(task.reload)
      end
    end

    def cancel
      with_idempotency do
        task = SourcingTask.find(params[:id])
        visible_person!(task.person_id)
        raise ArgumentError, "task_is_closed" unless task.open?

        task.cancel!
        emit(task, "task.cancelled")
        render json: serialize(task.reload)
      end
    end

    private

    def write(task, event)
      task.save!
      emit(task, event)
    rescue ActiveRecord::RecordInvalid => e
      raise ArgumentError, e.record.errors.full_messages.to_sentence
    end

    def emit(task, event)
      outcome = ChangeWriter.call(
        record: task, action: event, event_type: event,
        payload: { "person_id" => task.person_id, "title" => task.title, "task_type" => task.task_type }
      )
      TimelineProjector.call(outbox_event: outcome.outbox_event)
    end

    def task_params
      params.require(:task).permit(:person_id, :title, :description, :task_type, :due_at, :assignee_user_id,
        :assignee_agent_id, :application_id, :project_member_id)
    end

    def serialize(task)
      task.as_json(only: %i[
        id organization_id person_id sequence_enrollment_id assignee_user_id assignee_agent_id title description task_type
        status due_at completed_at pauses_enrollment application_id project_member_id created_at
      ]).merge("person" => ResourceSummary.person(task.person, fields: %i[id display_name primary_email]),
               "overdue" => task.open? && task.due_at.present? && task.due_at < Time.current)
    end

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end
  end
end
