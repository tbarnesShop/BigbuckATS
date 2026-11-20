# frozen_string_literal: true

module V1
  class ProjectsController < ApplicationController
    include PersonScoped

    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_project", title: error.message)
    end

    def index
      projects = ResourceVisibility.projects.includes(:pipeline, :job).order(:created_at).limit(100)
      render json: { data: projects.map { |p| serialize(p) } }
    end

    def show
      render json: serialize(ResourceVisibility.projects.includes(:pipeline, :job).find(params[:id]))
    end

    def create
      with_idempotency do
        pipeline = resolve_pipeline!
        project = Project.create!(
          name: project_params.require(:name),
          pipeline: pipeline,
          job_id: project_params[:job_id],
          confidential: ActiveModel::Type::Boolean.new.cast(project_params[:confidential]) || false,
          description: project_params[:description],
          owner_user_id: project_params[:owner_user_id].presence || Current.actor_id,
          saved_search_id: project_params[:saved_search_id],
          version: 1
        )
        ChangeWriter.call(
          record: project, action: "project.created", event_type: "project.created",
          payload: { "name" => project.name }, changes: { "name" => [ nil, project.name ] }
        )
        render json: serialize(project), status: :created
      end
    end

    def update
      with_idempotency do
        project = ResourceVisibility.projects.find(params[:id])
        attrs = project_params.slice(:name, :description, :owner_user_id, :saved_search_id)
        project.update!(attrs.to_h)
        ChangeWriter.call(
          record: project, action: "project.updated", event_type: "project.updated",
          payload: { "name" => project.name }, changes: project.saved_changes.slice(*attrs.keys)
        )
        render json: serialize(project)
      end
    end

    # Adds people by id, by ad-hoc search filters, or by the pool's own saved search (smart pool refresh).
    # POST /projects/:id/people  { person_ids: [], filters: {}, saved_search_id: "" }
    def add_people
      with_idempotency do
        project = ResourceVisibility.projects.find(params[:id])
        people = people_from_request(project)
        render json: add_to_pool(project, people), status: :created
      end
    end

    # Pulls a job's applicants (default: rejected and withdrawn, the silver medalists) into the pool.
    def add_from_job
      with_idempotency do
        project = ResourceVisibility.projects.find(params[:id])
        job = ResourceVisibility.jobs.find(params.require(:job_id))
        statuses = Array(params[:statuses]).presence || %w[rejected withdrawn]
        raise ArgumentError, "invalid_status" unless (statuses - Application::STATUSES).empty?

        ids = ResourceVisibility.applications.where(job_id: job.id, status: statuses).distinct.pluck(:person_id)
        render json: add_to_pool(project, ResourceVisibility.people.where(id: ids)), status: :created
      end
    end

    # Moves many members to one stage: POST /projects/:id/transitions { person_ids|member_ids, to_stage_key }
    def bulk_transition
      with_idempotency do
        project = ResourceVisibility.projects.find(params[:id])
        rows = ResourceVisibility.members.where(project_id: project.id, status: "active")
        rows = rows.where(id: Array(params[:member_ids])) if params[:member_ids].present?
        rows = rows.where(person_id: Array(params[:person_ids])) if params[:person_ids].present?
        raise ArgumentError, "members_required" if params[:member_ids].blank? && params[:person_ids].blank?

        moved = rows.limit(500).map { |m|
          SubjectTransitions.move(subject: m, to_stage_key: params.require(:to_stage_key), reason: params[:reason])
        }
        render json: { "moved" => moved.size }
      end
    end

    def members
      project = ResourceVisibility.projects.find(params[:id])
      rows = ResourceVisibility.members.includes(:person, :pipeline).where(project_id: project.id).order(:created_at)
      render json: { data: rows.map { |m| serialize_member(m) } }
    end

    def create_member
      with_idempotency do
        project = ResourceVisibility.projects.find(params[:id])
        person = ResourceVisibility.people.find(member_params.require(:person_id))
        existing = ProjectMember.find_by(project_id: project.id, person_id: person.id)
        raise ArgumentError, "already_a_member" if existing

        pipeline = project.pipeline
        member = ProjectMember.create!(
          project: project,
          person: person,
          pipeline: pipeline,
          pipeline_version: pipeline&.version,
          current_stage_key: pipeline&.first_stage_key,
          status: "active",
          version: 1
        )
        ChangeWriter.call(
          record: member, action: "project_member.added", event_type: "project_member.added",
          payload: { "project_id" => project.id, "person_id" => person.id }
        )
        render json: serialize_member(member), status: :created
      end
    end

    private

    MAX_POOL_ADD = 500

    def people_from_request(project)
      if params[:person_ids].present?
        ResourceVisibility.people.where(id: Array(params[:person_ids]).first(MAX_POOL_ADD))
      else
        filters = if params[:saved_search_id].present? || (params[:filters].blank? && project.saved_search_id.present?)
          SavedSearch.find(params[:saved_search_id].presence || project.saved_search_id).filters.to_h
        else
          PersonSearch.permitted_filters(params.require(:filters))
        end
        PersonSearch.call(viewer: viewer, filters: filters, limit: MAX_POOL_ADD)
      end
    end

    def add_to_pool(project, people)
      PoolAdder.call(project: project, people: people)
    end

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def project_params
      params.require(:project).permit(:name, :job_id, :pipeline_id, :confidential, :description, :owner_user_id, :saved_search_id)
    end

    def member_params
      params.require(:member).permit(:person_id)
    end

    def resolve_pipeline!
      if project_params[:pipeline_id].present?
        Pipeline.find(project_params[:pipeline_id])
      else
        SourcingPipeline.default!
      end
    end

    def serialize(project)
      pipeline = project.pipeline
      project.as_json(only: %i[id organization_id name description owner_user_id saved_search_id pipeline_id job_id confidential version created_at updated_at])
             .merge(
               "job" => ResourceSummary.job(project.job, fields: %i[id title status]),
               "pipeline" => pipeline && {
                 "id" => pipeline.id,
                 "stages" => Array(pipeline.resolved_stages)
               },
               "member_count" => ResourceVisibility.members.where(project_id: project.id, status: "active").count
             )
    end

    def serialize_member(member)
      member.as_json(
        only: %i[id organization_id project_id person_id pipeline_id current_stage_key status converted_application_id note added_by_user_id version created_at updated_at]
      ).merge(
        "person" => ResourceSummary.person(member.person, fields: %i[id display_name primary_email lifecycle_stage]),
        "pipeline" => member.pipeline && {
          "id" => member.pipeline.id,
          "stages" => Array(member.pipeline.resolved_stages)
        }
      )
    end
  end
end
