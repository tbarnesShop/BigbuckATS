# frozen_string_literal: true

module V1
  class ProjectMembersController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_project_member", title: error.message)
    end

    def index
      rows = ResourceVisibility.members.includes(:person, :pipeline, :project).order(:created_at)
      rows = rows.where(person_id: params[:person_id]) if params[:person_id].present?
      rows = rows.where(project_id: params[:project_id]) if params[:project_id].present?
      render json: { data: rows.limit(200).map { |m| serialize(m) } }
    end

    def show
      render json: serialize(ResourceVisibility.members.includes(:person, :pipeline, :project).find(params[:id]))
    end

    def update
      with_idempotency do
        member = ResourceVisibility.members.find(params[:id])
        member.update!(note: params.require(:member)[:note].to_s.presence)
        ChangeWriter.call(
          record: member, action: "project_member.updated", event_type: "project_member.updated",
          payload: { "project_id" => member.project_id, "person_id" => member.person_id },
          changes: member.saved_changes.slice("note")
        )
        render json: serialize(member.reload)
      end
    end

    def transitions
      member = ResourceVisibility.members.find(params[:id])
      rows = member.stage_transitions.map { |t|
        t.as_json(only: %i[id subject_type subject_id from_stage_key to_stage_key command reason actor_id created_at])
      }
      render json: { data: rows }
    end

    def create_transition
      with_idempotency do
        member = ResourceVisibility.members.find(params[:id])
        raise ArgumentError, "not_active" unless member.status == "active"
        raise ArgumentError, "pipeline_required" if member.pipeline.blank?

        command = transition_params[:command].presence || "move"
        member = case command
        when "move"
                   SubjectTransitions.move(
                     subject: member,
                     to_stage_key: transition_params.require(:to_stage_key),
                     reason: transition_params[:reason]
                   )
        when "reject"
                   SubjectTransitions.reject(
                     subject: member,
                     reason: transition_params.require(:reason)
                   )
        when "withdraw"
                   SubjectTransitions.withdraw(
                     subject: member,
                     reason: transition_params[:reason]
                   )
        else
                   raise ArgumentError, "unknown command"
        end
        render json: serialize(member.reload), status: :created
      end
    end

    def convert
      with_idempotency do
        member = ResourceVisibility.members.find(params[:id])
        job = if params[:job_id].present?
                ResourceVisibility.jobs.find(params[:job_id])
        else
                member.project.job
        end
        application = ProjectConversion.call(member: member, job: job)
        render json: {
          "member" => serialize(member.reload),
          "application" => application.as_json(
            only: %i[id job_id person_id status current_stage_key pipeline_id]
          )
        }, status: :created
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def transition_params
      params.permit(:command, :to_stage_key, :reason, transition: %i[command to_stage_key reason])
            .tap do |p|
              nested = p.delete(:transition)
              p.merge!(nested) if nested.present?
            end
    end

    def serialize(member)
      member.as_json(
        only: %i[id organization_id project_id person_id pipeline_id current_stage_key status converted_application_id note added_by_user_id version created_at updated_at]
      ).merge(
        "person" => ResourceSummary.person(member.person, fields: %i[id display_name primary_email lifecycle_stage]),
        "project" => member.project&.as_json(only: %i[id name job_id]),
        "pipeline" => member.pipeline && {
          "id" => member.pipeline.id,
          "stages" => Array(member.pipeline.resolved_stages)
        }
      )
    end
  end
end
