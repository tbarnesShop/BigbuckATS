# frozen_string_literal: true

module V1
  class InterviewsController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_interview", title: error.message)
    end

    # Interviews across all jobs, soonest first. `tab` narrows the list
    # (see InterviewHub). Ids only: names come from the application/person,
    # whose visibility rules are applied where those records are read.
    def index
      scope = InterviewHub.list(tab: params[:tab], actor_id: Current.actor_id)
      render json: { data: scope.map { |row| serialize(row).merge("job_id" => row.application&.job_id) } }
    end

    def show
      render json: serialize(Interview.find(params[:id]))
    end

    # Candidates in an interview stage with planned interviews still to book.
    def awaiting_schedule
      rows = InterviewHub.awaiting_schedule(actor_id: Current.actor_id, mine: params[:scope] == "mine")
      render json: {
        data: rows.map { |row|
          app = row[:app]
          {
            "application_id" => app.id,
            "person" => ResourceSummary.person(app.person, fields: %i[id display_name]),
            "job" => app.job && { "id" => app.job.id, "title" => app.job.title },
            "stage" => { "key" => row[:stage]["key"], "name" => row[:stage]["name"] },
            "missing" => row[:missing].map { |item| item.slice("key", "name", "required") },
            "waiting_since" => app.updated_at
          }
        }
      }
    end

    def cancel
      with_idempotency do
        interview = Interview.find(params[:id])
        InterviewLifecycle.cancel!(interview: interview, reason: params[:reason])
        render json: serialize(interview.reload)
      end
    end

    def reschedule
      with_idempotency do
        interview = Interview.find(params[:id])
        emails = params.require(:user_emails)
        email_hash = emails.respond_to?(:to_unsafe_h) ? emails.to_unsafe_h : emails.to_h
        InterviewLifecycle.reschedule!(
          interview: interview,
          starts_at: Time.zone.parse(params.require(:starts_at)),
          ends_at: Time.zone.parse(params.require(:ends_at)),
          interviewer_user_ids: params[:interviewer_user_ids],
          organizer_calendar: params.require(:organizer_calendar),
          user_emails: email_hash
        )
        render json: serialize(interview.reload)
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def serialize(interview)
      interview.as_json(
        only: %i[id application_id stage_key interview_key status starts_at ends_at interviewer_user_ids created_at]
      )
    end
  end
end
