# frozen_string_literal: true

module V1
  class JobsController < ApplicationController
    before_action :require_tenant!

    def index
      jobs = ResourceVisibility.jobs.includes(:pipeline, :requisition, hiring_team: { members: :user }).order(:created_at).limit(100)
      dimensions = dimension_rows(jobs)
      render json: { data: jobs.map { |j| serialize(j, dimensions: dimensions[j.id] || []) } }
    end

    def show
      job = ResourceVisibility.jobs.includes(:pipeline, :requisition, hiring_team: { members: :user }).find(params[:id])
      render json: serialize(job, dimensions: dimension_rows([ job ])[job.id] || []).merge("assignable_members" => assignable_members)
    end

    # What the new-job form offers: departments (so the job is grouped on careers) and the members who
    # can be its hiring manager (who approve its offers).
    def form_options
      render json: { "departments" => department_options, "members" => assignable_members }
    end

    def update
      job = ResourceVisibility.jobs.includes(:pipeline, :requisition, hiring_team: { members: :user }).find(params[:id])
      attrs = params.require(:job).permit(:openings, :careers_visibility).to_h
      if attrs.key?("openings")
        value = Integer(attrs["openings"], exception: false)
        if value.nil? || value.negative?
          return render_problem(status: :unprocessable_entity, code: "invalid_openings", title: "openings must be zero or more")
        end
        attrs["openings"] = value
      end
      published = params.dig(:job, :careers_published)
      if params[:job].key?(:careers_published) && ![ true, false ].include?(published)
        return render_problem(status: :unprocessable_entity, code: "invalid_publication", title: "careers_published must be a boolean")
      end
      Job.transaction do
        job.lock!
        job.update!(attrs)
        changes = job.saved_changes.except("updated_at", "version")
        unless published.nil?
          previous_published = job.postings.exists?(status: "published")
          if published
            posting = job.postings.find_by(status: "published") || job.postings.order(:created_at, :id).first || job.postings.build(title: job.title)
            posting.publish!
          else
            job.postings.where(status: "published").each { |posting| posting.update!(status: "draft") }
          end
          changes["careers_published"] = [ previous_published, published ] if previous_published != published
        end
        if changes.any?
          ChangeWriter.call(
            record: job, action: "job.updated", event_type: "job.updated",
            payload: attrs.merge("careers_published" => published).compact, changes: changes
          )
        end
      end
      render json: serialize(job.reload, dimensions: dimension_rows([ job ])[job.id] || [])
    rescue ArgumentError => error
      render_problem(status: :unprocessable_entity, code: "invalid_publication", title: error.message)
    end

    def create
      with_idempotency do
        pipeline = if params[:pipeline_id].present? || job_params[:pipeline_id].present?
                     Pipeline.find(params[:pipeline_id].presence || job_params[:pipeline_id])
        else
                     template = PipelineTemplate.order(:created_at).first ||
                                PipelineTemplate.create!(key: "default", name: "Default", object_type: "job").tap { |t|
                                  t.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
                                }
                     Pipeline.build_from_template!(template: template)
        end
        requisition = Requisition.find(job_params[:requisition_id]) if job_params[:requisition_id].present?
        department = department_value!(params.dig(:job, :department_id))
        hiring_manager = hiring_manager_membership!(params.dig(:job, :hiring_manager_user_id))
        job = Job.create!(
          title: job_params[:title],
          status: job_params[:status] || "active",
          careers_visibility: job_params[:careers_visibility] || "public",
          pipeline: pipeline,
          requisition: requisition
        )
        ChangeWriter.call(
          record: job, action: "job.created", event_type: "job.created",
          payload: { "title" => job.title, "requisition_id" => job.requisition_id },
          changes: { "title" => [ nil, job.title ] }
        )
        # A new job is usable straight away: its creator is on the hiring team (so interviews can be
        # scheduled), and unless it is hidden it has a published posting (so it shows on careers).
        creator = creator_membership
        if creator || hiring_manager
          team = HiringTeam.create!(job: job)
          team.members.create!(user_id: creator.user_id, team_role: "recruiter") if creator
          team.members.create!(user_id: hiring_manager.user_id, team_role: "hiring-manager") if hiring_manager
        end
        if department
          EntityDimensionValue.create!(entity_type: "Job", entity_id: job.id, dimension: department.dimension,
            dimension_value: department)
        end
        unless job.careers_visibility == "hidden" || job.status != "active"
          posting = job.postings.build(title: job.title, audience: job.careers_visibility, status: "published",
            description: params.dig(:job, :description).presence, location: params.dig(:job, :location).presence,
            employment_type: params.dig(:job, :employment_type).presence)
          # Optional question template: its current questions are copied onto the posting, as on the postings page.
          if (template_id = params.dig(:job, :question_template_id).presence)
            template = ApplicationQuestionTemplate.find(template_id)
            raise ArgumentError, "This template is archived" unless template.status == "active"
            posting.assign_attributes(question_template: template, template_questions: template.questions.deep_dup,
              template_version: template.version)
          end
          posting.save!
          ChangeWriter.call(record: posting, action: "posting.created", event_type: "posting.created")
        end
        render json: serialize(job.reload), status: :created
      end
    end

    # Team roles are hyphenated (approval policies resolve "role:hiring-manager"); underscores are accepted.
    TEAM_ROLES = %w[hiring-manager recruiter coordinator interviewer].freeze

    def add_team_member
      job = ResourceVisibility.jobs.find(params[:id])
      role = params.require(:team_role).to_s.tr("_", "-")
      return render_problem(status: :unprocessable_entity, code: "invalid_team_role", title: "Choose hiring manager, recruiter, coordinator or interviewer.") unless TEAM_ROLES.include?(role)
      membership = Membership.find_by(user_id: params.require(:user_id), status: "active")
      return render_problem(status: :unprocessable_entity, code: "not_a_member", title: "Choose an active member of this organization.") unless membership
      Job.transaction do
        job.lock!
        team = job.hiring_team || HiringTeam.create!(job: job)
        member = team.members.find_or_initialize_by(user_id: membership.user_id, team_role: role)
        if member.new_record?
          member.save!
          ChangeWriter.call(record: job, action: "job.team_member_added", event_type: "job.updated",
            payload: { "user_id" => membership.user_id, "team_role" => role })
        end
      end
      render json: serialize(reload_job(job)), status: :created
    end

    def update_team_member
      job = ResourceVisibility.jobs.find(params[:id])
      role = params.require(:team_role).to_s.tr("_", "-")
      return render_problem(status: :unprocessable_entity, code: "invalid_team_role", title: "Choose hiring manager, recruiter, coordinator or interviewer.") unless TEAM_ROLES.include?(role)
      Job.transaction do
        job.lock!
        member = team_member!(job)
        if member.team_role != role
          if job.hiring_team.members.exists?(user_id: member.user_id, team_role: role)
            return render_problem(status: :conflict, code: "already_on_team", title: "This person already has that role on the job.")
          end
          previous = member.team_role
          member.update!(team_role: role)
          ChangeWriter.call(record: job, action: "job.team_member_updated", event_type: "job.updated",
            payload: { "user_id" => member.user_id, "team_role" => role }, changes: { "team_role" => [ previous, role ] })
        end
      end
      render json: serialize(reload_job(job))
    end

    # Taking someone off a job's hiring team is a reversible staffing change (re-adding is one click),
    # so the lab allows it; see DemoPolicy::REVERSIBLE_ACTIONS.
    def remove_team_member
      job = ResourceVisibility.jobs.find(params[:id])
      Job.transaction do
        job.lock!
        member = team_member!(job)
        member.destroy!
        ChangeWriter.call(record: job, action: "job.team_member_removed", event_type: "job.updated",
          payload: { "user_id" => member.user_id, "team_role" => member.team_role })
      end
      render json: serialize(reload_job(job))
    end

    PIPELINE_OPS = %w[add_stage rename_stage move_stage remove_stage add_interview remove_interview].freeze
    STAGE_TYPES = %w[apply screen review interview offer].freeze

    # Job-level pipeline edits are stored as overrides on the template, so template updates still flow in.
    def update_pipeline
      job = ResourceVisibility.jobs.includes(:pipeline).find(params[:id])
      op = params.require(:op).to_s
      return render_problem(status: :unprocessable_entity, code: "invalid_pipeline_edit", title: "Unknown pipeline change.") unless PIPELINE_OPS.include?(op)
      Job.transaction do
        job.lock!
        pipeline = job.pipeline
        pipeline.lock!
        if Job.where(pipeline_id: pipeline.id).where.not(id: job.id).exists? || Project.where(pipeline_id: pipeline.id).exists?
          raise ArgumentError, "shared_pipeline"
        end
        stages = Array(pipeline.resolved_stages)
        key = params[:key].to_s
        target = stages.find { |stage| stage["key"] == key }
        raise ArgumentError, "stage_missing" if op != "add_stage" && target.nil?
        raise ArgumentError, "hired_stage_is_fixed" if target && target["type"] == "hired"
        edit =
          case op
          when "add_stage"
            name = params.require(:name).to_s.strip
            type = params[:type].presence || "interview"
            raise ArgumentError, "stage_name_required" if name.blank?
            raise ArgumentError, "invalid_stage_type" unless STAGE_TYPES.include?(type)
            base = name.parameterize.presence || "stage"
            new_key = base
            n = 1
            new_key = "#{base}-#{n += 1}" while stages.any? { |stage| stage["key"] == new_key }
            working = stages.reject { |stage| stage["type"] == "hired" }
            # Default placement follows the stage kind: an offer stage goes last; anything else goes before
            # the first offer stage, so a new screen does not land after Offer.
            first_offer = working.index { |stage| stage["type"] == "offer" }
            default_after =
              if type == "offer" || first_offer.nil? || first_offer.zero? then working.last&.dig("key")
              else working[first_offer - 1]["key"]
              end
            after = params[:after].presence || default_after
            { "op" => "add_stage", "key" => new_key, "name" => name, "type" => type, "after" => after }.compact
          when "rename_stage"
            name = params.require(:name).to_s.strip
            raise ArgumentError, "stage_name_required" if name.blank?
            { "op" => "update_stage", "key" => key, "name" => name }
          when "move_stage"
            working = stages.reject { |stage| stage["type"] == "hired" }
            i = working.index { |stage| stage["key"] == key }
            j = params[:direction].to_s == "up" ? i - 1 : i + 1
            raise ArgumentError, "cannot_move_stage" if j.negative? || j >= working.size
            order = working.map { |stage| stage["key"] }
            order[i], order[j] = order[j], order[i]
            pos = order.index(key)
            { "op" => "move_stage", "key" => key, "after" => pos.zero? ? nil : order[pos - 1] }
          when "add_interview"
            name = params.require(:name).to_s.strip
            raise ArgumentError, "interview_name_required" if name.blank?
            base = name.parameterize.presence || "interview"
            interview_key = base
            n = 1
            interview_key = "#{base}-#{n += 1}" while Array(target["interviews"]).any? { |row| row["key"] == interview_key }
            rubric = params[:rubric_key].presence
            raise ArgumentError, "rubric_not_found" if rubric && !ScorecardRubric.exists?(key: rubric)
            interview = { "key" => interview_key, "name" => name, "required" => params[:required].to_s != "false",
                          "rubric_key" => rubric }.compact
            minutes = params[:duration_minutes].to_i
            interview["duration_minutes"] = minutes if minutes.positive?
            { "op" => "add_interview", "stage" => key, "interview" => interview }
          when "remove_interview"
            interview_key = params.require(:interview_key).to_s
            raise ArgumentError, "interview_missing" unless Array(target["interviews"]).any? { |row| row["key"] == interview_key }
            { "op" => "remove_interview", "stage" => key, "interview" => interview_key }
          when "remove_stage"
            raise ArgumentError, "stage_has_candidates" if Application.where(pipeline_id: pipeline.id, current_stage_key: key).exists?
            raise ArgumentError, "last_stage" if stages.count { |stage| stage["type"] != "hired" } <= 1
            { "op" => "remove_stage", "key" => key }
          end
        previous = stages.map { |stage| stage["key"] }
        if pipeline.pipeline_template
          pipeline.overrides = Array(pipeline.overrides) + [ edit ]
          result = pipeline.reresolve!
          raise ArgumentError, "pipeline_conflict:#{result.conflicts.last["reason"]}" if result.conflicts.any? { |c| c["edit_index"] == pipeline.overrides.size - 1 }
        else
          result = PipelineResolver.call(template_stages: stages.reject { |stage| stage["type"] == "hired" }, overrides: [ edit ])
          raise ArgumentError, "pipeline_conflict:#{result.conflicts.first["reason"]}" if result.conflicts.any?
          pipeline.update!(resolved_stages: Pipeline.with_hired_stage(result.stages), version: pipeline.version + 1)
        end
        ChangeWriter.call(record: job, action: "job.pipeline_updated", event_type: "job.updated",
          payload: edit, changes: { "stages" => [ previous, pipeline.stage_keys ] })
      end
      render json: serialize(reload_job(job))
    rescue ArgumentError => error
      render_problem(status: :unprocessable_entity, code: "invalid_pipeline_edit", title: error.message)
    end

    def rediscovery
      job = ResourceVisibility.jobs.find(params[:id])
      viewer =
        if current_principal
          PrincipalViewer.new(current_principal)
        elsif Current.actor_id.present?
          Membership.find_by(user_id: Current.actor_id, status: "active")
        end
      signals = TalentRediscovery.call(job: job, viewer: viewer, limit: params[:limit] || 50)
      render json: {
        data: signals.map { |s|
          {
            "person" => ResourceSummary.person(s.person, fields: %i[id display_name primary_email lifecycle_stage]),
            "score" => s.score,
            "reasons" => s.reasons,
            "past_applications" => s.past_applications.map { |a|
              a.as_json(only: %i[id job_id status current_stage_key updated_at]).merge(
                "job" => ResourceSummary.job(a.job, fields: %i[id title status])
              )
            }
          }
        }
      }
    end

    private

    def team_member!(job)
      team = job.hiring_team or raise ActiveRecord::RecordNotFound
      team.members.find(params[:member_id])
    end

    def reload_job(job)
      ResourceVisibility.jobs.includes(:pipeline, :requisition, hiring_team: { members: :user }).find(job.id)
    end

    def creator_membership
      return nil if Current.actor_id.blank? || Current.agent_id.present?
      Membership.find_by(user_id: Current.actor_id, status: "active")
    end

    def department_options
      dimension = Dimension.find_by(key: "department")
      return [] unless dimension

      DimensionValue.where(dimension: dimension).order(:label).map do |value|
        { "id" => value.id, "key" => value.key, "label" => value.label }
      end
    end

    def department_value!(id)
      return nil if id.blank?

      value = DimensionValue.joins(:dimension).find_by(id: id, dimensions: { key: "department" })
      raise ArgumentError, "invalid_department" unless value
      value
    end

    def hiring_manager_membership!(user_id)
      return nil if user_id.blank?

      Membership.find_by(user_id: user_id, status: "active") || raise(ArgumentError, "not_a_member")
    end

    # Active members, for the hiring-team picker on the job page (same job.read gate as the job itself).
    def assignable_members
      Membership.includes(:user, :role).where(status: "active").filter_map do |member|
        next unless member.user
        { "user_id" => member.user_id, "name" => member.user.name, "email" => member.user.email, "role_key" => member.role&.key }
      end.sort_by { |row| row["name"].to_s }
    end

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def job_params
      params.require(:job).permit(:title, :status, :pipeline_id, :requisition_id, :careers_visibility)
    end

    def serialize(job, dimensions: nil)
      pipeline = job.pipeline
      job.as_json(only: %i[id organization_id title status openings careers_visibility confidential code_name pipeline_id requisition_id version created_at updated_at]).merge(
        "careers_published" => job.postings.exists?(status: "published"),
        "pipeline" => pipeline && {
          "id" => pipeline.id,
          "stages" => Array(pipeline.resolved_stages)
        },
        "requisition" => job.requisition&.as_json(only: %i[id code title headcount status]),
        "dimensions" => dimensions || dimension_rows([ job ])[job.id] || [],
        "hiring_team" => hiring_team_rows(job),
        "posting" => primary_posting(job)
      )
    end

    # The posting the job page edits: the published one, else the oldest.
    def primary_posting(job)
      posting = job.postings.min_by { |row| [ row.status == "published" ? 0 : 1, row.created_at ] }
      posting&.as_json(only: %i[id title description location employment_type audience status version])
    end

    def dimension_rows(jobs)
      return {} if jobs.empty?

      EntityDimensionValue.where(entity_type: "Job", entity_id: jobs.map(&:id))
                          .includes(:dimension, :dimension_value)
                          .group_by(&:entity_id)
                          .transform_values { |rows| dimension_payload(rows) }
    end

    def dimension_payload(rows)
      rows.filter_map do |row|
        dimension = row.dimension
        value = row.dimension_value
        next unless dimension && value

        { "key" => dimension.key, "label" => dimension.label, "value" => value.label }
      end
    end

    def hiring_team_rows(job)
      team = job.hiring_team
      return [] unless team

      team.members.map do |member|
        { "id" => member.id, "user_id" => member.user_id, "name" => member.user&.name, "email" => member.user&.email, "role" => member.team_role }
      end
    end
  end
end
