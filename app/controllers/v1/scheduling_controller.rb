# frozen_string_literal: true

module V1
  class SchedulingController < ApplicationController
    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_scheduling", title: error.message)
    end

    def public_show
      link = SchedulingLinkToken.verify(params[:token])
      Current.organization_id = link.organization_id
      application = Application.includes(:job, :person).find(link.application_id)
      org = Organization.find(link.organization_id)
      render json: {
        "id" => link.id,
        "kind" => link.kind,
        "interview_keys" => link.interview_keys,
        "expires_at" => link.expires_at,
        "used_at" => link.used_at,
        "usable" => link.used_at.blank? && link.revoked_at.blank? && link.expires_at > Time.current,
        "organization" => { "name" => org.name, "slug" => org.slug },
        "application" => {
          "id" => application.id,
          "job_title" => application.job&.title,
          "person_name" => application.person&.display_name
        }
      }
    end

    def public_book
      block_demo_public_write!(SchedulingLinkToken.verify(params[:token]).organization_id, action: "schedule")
      result = SelfSchedule.book!(
        token: params[:token],
        interview_defs: booking_interview_defs,
        profiles: booking_profiles,
        organizer_calendar: params.require(:organizer_calendar),
        user_emails: booking_user_emails,
        search_start: Time.zone.parse(params.require(:search_start)),
        search_end: Time.zone.parse(params.require(:search_end))
      )
      render json: {
        "booked" => true,
        "interviews" => result.interviews.map { |i|
          i.as_json(only: %i[id interview_key status starts_at ends_at])
        }
      }
    end

    private

    def booking_interview_defs
      Array(params.require(:interview_defs)).map do |row|
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
  end
end
