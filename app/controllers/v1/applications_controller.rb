# frozen_string_literal: true

module V1
  class ApplicationsController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError, StageGuards::Error do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_transition", title: error.message)
    end

    def index
      scope = ResourceVisibility.applications.includes(:person, :job, :pipeline)
      scope = scope.where(job_id: params[:job_id]) if params[:job_id].present?
      scope = scope.where(person_id: params[:person_id]) if params[:person_id].present?
      if params[:status] == "archived"
        # "Archived" is the recruiter word for closed without a hire: rejected or withdrawn.
        scope = scope.where(status: %w[rejected withdrawn])
      elsif params[:status].present?
        unless Application::STATUSES.include?(params[:status])
          return render_problem(status: :unprocessable_entity, code: "invalid_filter", title: "unknown_status:#{params[:status]}")
        end

        scope = scope.where(status: params[:status])
      end
      scope = scope.where(current_stage_key: params[:stage]) if params[:stage].present?
      scope = mine_first(scope)
      total = scope.unscope(:order).count(:id)
      page = [ params[:page].to_i, 1 ].max
      per = if params[:per_page].present?
              [ [ params[:per_page].to_i, 1 ].max, 100 ].min
      elsif params[:page].present?
              25
      else
              100
      end
      rows = scope.offset((page - 1) * per).limit(per).to_a
      closings = closing_transitions(rows)
      render json: {
        data: rows.map { |a| serialize(a).merge(closings[a.id] || {}) },
        meta: { "page" => page, "per_page" => per, "total" => total }
      }
    end

    def show
      render json: serialize(ResourceVisibility.applications.includes(:person, :job, :pipeline).find(params[:id]))
    end

    def create
      with_idempotency do
        job = ResourceVisibility.jobs.find(application_params[:job_id])
        person = ResourceVisibility.people.find(application_params[:person_id])
        application = if application_params[:consents].present?
                        ApplyCompliance.apply!(
                          person: person, job: job, locale: application_params[:locale] || "en",
                          granted_purpose_keys: Array(application_params[:consents])
                        )
        else
                        ApplicationCreator.call(job: job, person: person)
        end
        render json: serialize(application.reload), status: :created
      end
    end

    def transitions
      application = ResourceVisibility.applications.find(params[:id])
      rows = application.stage_transitions.map { |t| serialize_transition(t) }
      render json: { data: rows }
    end

    def create_transition
      with_idempotency do
        application = ResourceVisibility.applications.find(params[:id])
        command = transition_params[:command].presence || "move"
        application = case command
        when "move"
                        SubjectTransitions.move(
                          subject: application,
                          to_stage_key: transition_params.require(:to_stage_key),
                          reason: transition_params[:reason]
                        )
        when "reject"
                        SubjectTransitions.reject(
                          subject: application,
                          reason: transition_params.require(:reason)
                        )
        when "withdraw"
                        SubjectTransitions.withdraw(
                          subject: application,
                          reason: transition_params[:reason]
                        )
        when "hire"
                        SubjectTransitions.hire(subject: application)
        else
                        raise ArgumentError, "unknown command"
        end
        render json: serialize(application.reload), status: :created
      end
    end

    def create_offer
      with_idempotency do
        application = ResourceVisibility.applications.find(params[:id])
        fields = offer_params[:fields].present? ? offer_params[:fields].to_unsafe_h : {}
        offer = OfferSubmitter.create_draft!(application: application, fields: fields)
        render json: serialize_offer(offer), status: :created
      end
    end

    def interviews
      application = ResourceVisibility.applications.find(params[:id])
      interviews = Interview.where(application_id: application.id).order(:starts_at).to_a
      # Who has handed feedback in, never what it says: everyone on the application can see what is
      # still owed, while the scorecards themselves follow ScorecardVisibility.
      submitted = Scorecard.where(interview_id: interviews.map(&:id), status: "submitted")
                           .pluck(:interview_id, :user_id).group_by(&:first)
      rows = interviews.map do |i|
        serialize_interview(i).merge("feedback_submitted_user_ids" => Array(submitted[i.id]).map(&:last))
      end
      render json: { data: rows }
    end

    # Feedback still owed in the candidate's current stage. It warns the person moving them; the move
    # is refused only when `blocking` is true (the stage's exit rules name scorecards_submitted).
    def missing_feedback
      application = ResourceVisibility.applications.find(params[:id])
      missing = StageGuards.missing_scorecards(subject: application, stage_key: application.current_stage_key)
      blocking = missing.any? &&
                 StageGuards.scorecards_required?(subject: application, stage_key: application.current_stage_key)
      render json: { stage_key: application.current_stage_key, blocking: blocking, data: missing }
    end

    def create_scheduling_link
      with_idempotency do
        application = ResourceVisibility.applications.find(params[:id])
        keys = Array(params[:interview_keys]).presence || %w[screen]
        issued = SelfSchedule.create_link!(
          application: application,
          interview_keys: keys,
          expires_at: params[:expires_at].present? ? Time.zone.parse(params[:expires_at]) : 7.days.from_now
        )
        render json: {
          "id" => issued[:link].id,
          "application_id" => application.id,
          "kind" => issued[:link].kind,
          "interview_keys" => issued[:link].interview_keys,
          "expires_at" => issued[:link].expires_at,
          "token" => issued[:token]
        }, status: :created
      end
    end

    def booking_options
      application = ResourceVisibility.applications.find(params[:id])
      options = PanelBookingProposal.suggest(application: application, **booking_input)
      render json: { options: options }
    end

    def create_booking
      with_idempotency do
        application = ResourceVisibility.applications.find(params[:id])
        result = if params[:booking_token].present?
                   PanelBookingProposal.confirm!(application: application, token: params[:booking_token])
        else
                   PanelBooking.suggest_and_book!(application: application, **booking_input)
        end
        raise ArgumentError, "booking_failed:#{result.refused_reason}" unless result.booked

        render json: {
          "booked" => true,
          "interviews" => result.interviews.map { |i| serialize_interview(i) }
        }, status: :created
      end
    end

    private

    def booking_input
      {
        interview_defs: booking_interview_defs, profiles: booking_profiles,
        user_emails: booking_user_emails, organizer_calendar: params.require(:organizer_calendar),
        search_start: Time.zone.parse(params.require(:search_start)),
        search_end: Time.zone.parse(params.require(:search_end))
      }
    end

    def offer_params
      params.fetch(:offer, {}).permit(fields: {})
    end

    # Hiring-team jobs and owned people sort ahead of everything else.
    # Default order stays created_at so existing callers keep their sequence.
    def mine_first(scope)
      return scope.order(:created_at) unless params[:sort] == "mine" && Current.actor_id.present?

      actor = Current.actor_id
      job_ids = HiringTeam.joins(:members).where(hiring_team_members: { user_id: actor }).pluck(:job_id)
      mine = scope.where(job_id: job_ids) if job_ids.any?
      owned = scope.where(person_id: Person.where(owner_user_id: actor).select(:id))
      ids = []
      ids.concat(mine.pluck(:id)) if mine
      ids.concat(owned.pluck(:id))
      ids.uniq!
      return scope.order(:created_at) if ids.empty?

      priority = Arel::Nodes::Case.new.when(Application.arel_table[:id].in(ids)).then(0).else(1)
      scope.order(priority, :created_at)
    end

    def booking_interview_defs
      raw = params.require(:interview_defs)
      Array(raw).map do |row|
        h = row.permit(:key, :duration_minutes, :count, candidate_user_ids: []).to_h
        {
          key: h["key"],
          duration_minutes: h["duration_minutes"].to_i,
          count: (h["count"] || 1).to_i,
          candidate_user_ids: Array(h["candidate_user_ids"])
        }
      end
    end

    def booking_profiles
      Array(params.require(:profiles)).map do |row|
        h = row.permit(:user_id, :paused).to_h
        { user_id: h["user_id"], paused: ActiveModel::Type::Boolean.new.cast(h["paused"]) }
      end
    end

    def booking_user_emails
      raw = params.require(:user_emails)
      raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    end

    def serialize_offer(offer)
      offer.as_json(only: %i[id organization_id application_id status current_version_id version created_at updated_at])
           .merge("fields" => OfferFieldPolicy.for_current(offer.current_version&.fields))
    end

    def serialize_interview(interview)
      interview.as_json(
        only: %i[id application_id stage_key interview_key status starts_at ends_at interviewer_user_ids created_at]
      )
    end


    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def application_params
      params.require(:application).permit(:job_id, :person_id, :locale, consents: [])
    end

    def transition_params
      params.permit(:command, :to_stage_key, :reason, transition: %i[command to_stage_key reason])
            .tap do |p|
              nested = p.delete(:transition)
              p.merge!(nested) if nested.present?
            end
    end

    # Why and when each closed application was closed (reject/withdraw/hire reason), in one query.
    def closing_transitions(rows)
      closed = rows.reject { |a| a.status == "active" }.map(&:id)
      return {} if closed.empty?
      StageTransition.where(subject_type: "Application", subject_id: closed, command: %w[reject withdraw hire])
                     .order(:created_at).to_a.group_by(&:subject_id)
                     .transform_values { |list| { "closed_reason" => list.last.reason, "closed_at" => list.last.created_at } }
    end

    def serialize(application)
      pipeline = application.pipeline
      application.as_json(
        only: %i[id organization_id job_id person_id posting_id application_form_snapshot application_answers status current_stage_key pipeline_id version created_at updated_at]
      ).merge(
        "person" => person_summary(application.person),
        "job" => job_summary(application.job),
        "pipeline" => pipeline_summary(pipeline),
        "offers" => Offer.where(application_id: application.id).order(:created_at).map { |o|
          o.as_json(only: %i[id status current_version_id created_at])
        }
      )
    end

    def serialize_transition(transition)
      transition.as_json(
        only: %i[id subject_type subject_id from_stage_key to_stage_key command reason actor_id created_at]
      )
    end

    def person_summary(person)
      return nil unless person
      ResourceSummary.person(person)
    end

    def job_summary(job)
      return nil unless job
      ResourceSummary.job(job)
    end

    def pipeline_summary(pipeline)
      return nil unless pipeline
      {
        "id" => pipeline.id,
        "stages" => Array(pipeline.resolved_stages)
      }
    end
  end
end
