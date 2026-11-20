# frozen_string_literal: true

module V1
  # Criteria-based rediscovery for a job and the review queue it feeds.
  class RediscoveryController < ApplicationController
    include PersonScoped

    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_rediscovery", title: error.message)
    end

    KINDS = %w[must nice].freeze
    MATCH_KEYS = %w[q tag location title company source].freeze

    def criteria
      render json: { "job_id" => job.id, "criteria" => Array(job.criteria) }
    end

    def update_criteria
      with_idempotency do
        list = Array(params[:criteria]).map { |c| normalize_criterion(c) }
        raise ArgumentError, "too_many_criteria" if list.size > 20

        job.update!(criteria: list)
        ChangeWriter.call(
          record: job, action: "job.criteria_updated", event_type: "job.updated",
          payload: { "criteria_count" => list.size }, changes: { "criteria" => [ nil, list.size ] }
        )
        render json: { "job_id" => job.id, "criteria" => list }
      end
    end

    def run
      with_idempotency do
        raise ArgumentError, "criteria_required" if Array(job.criteria).empty?

        result = RediscoveryEngine.run!(job: job, viewer: viewer, found_by_agent_id: current_principal&.try(:agent_id))
        render json: { "created" => result.created, "refreshed" => result.refreshed, "skipped" => result.skipped,
                       "buckets" => result.buckets }
      end
    end

    def queue
      rows = RediscoveryCandidate.where(job_id: job.id, person_id: ResourceVisibility.people.select(:id))
                                 .includes(:person).order(score: :desc, created_at: :asc)
      rows = rows.where(status: params[:status]) if params[:status].present?
      rows = rows.where(bucket: params[:bucket]) if params[:bucket].present?
      render json: {
        data: rows.limit(200).map { |r| serialize(r) },
        meta: { "buckets" => rows.reorder(nil).group(:bucket).count, "statuses" => rows.reorder(nil).group(:status).count }
      }
    end

    # POST /rediscovery_candidates/:id/review { action, feedback, project_id, sequence_id, mailbox_id }
    def review
      with_idempotency do
        candidate = RediscoveryCandidate.find(params[:id])
        person = visible_person!(candidate.person_id)
        action = params.require(:review_action).to_s
        status = RediscoveryCandidate::ACTIONS.fetch(action) { raise ArgumentError, "unknown_action" }
        outcome = perform(action, candidate, person)
        candidate.update!(status: status, feedback: params[:feedback].presence || candidate.feedback,
                          reviewed_by_user_id: Current.actor_id, reviewed_at: Time.current)
        render json: serialize(candidate.reload).merge("outcome" => outcome)
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def job
      @job ||= ResourceVisibility.jobs.find(params[:job_id] || params[:id])
    end

    def perform(action, candidate, person)
      case action
      when "add_to_pool"
        project = params[:project_id].present? ? ResourceVisibility.projects.find(params[:project_id]) : job_pool!(candidate.job)
        PoolAdder.call(project: project, people: [ person ]).merge("project_id" => project.id)
      when "enroll"
        require_permission!("sequence.enroll")
        sequence = Sequence.find(params.require(:sequence_id))
        mailbox = params[:mailbox_id].present? ? Mailbox.find(params[:mailbox_id]) : Mailbox.order(:created_at).first || raise(ArgumentError, "mailbox_required")
        { "enrollment_id" => SequenceRunner.enroll!(sequence: sequence, person: person, mailbox: mailbox).id }
      else
        {}
      end
    end

    # The pool a job's rediscovered people land in, created on first use.
    def job_pool!(job)
      Project.find_by(job_id: job.id, name: "#{job.title} – rediscovery") || Project.create!(
        name: "#{job.title} – rediscovery", job_id: job.id, pipeline: SourcingPipeline.default!,
        confidential: job.confidential, owner_user_id: Current.actor_id, version: 1
      )
    end

    def normalize_criterion(raw)
      c = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
      c = c.stringify_keys
      kind = c["kind"].to_s
      raise ArgumentError, "criterion_kind_invalid" unless KINDS.include?(kind)
      raise ArgumentError, "criterion_label_required" if c["label"].blank?

      match = (c["match"] || {}).to_h.stringify_keys.slice(*MATCH_KEYS).compact_blank
      raise ArgumentError, "criterion_match_required" if match.empty?

      { "id" => c["id"].presence || "c-#{SecureRandom.hex(3)}", "label" => c["label"].to_s.first(120), "kind" => kind, "match" => match }
    end

    def serialize(row)
      row.as_json(only: %i[id job_id person_id status bucket score verdicts reasons feedback reviewed_at created_at])
         .merge("person" => ResourceSummary.person(row.person, fields: %i[id display_name primary_email lifecycle_stage]))
    end
  end
end
