# frozen_string_literal: true

# Recruiter home: feedback owed, new applicants still on the first stage,
# this week's interviews, offers waiting on approval, and active jobs.
# Rows are records and ids. Names stay on person and job reads, which apply
# visibility rules.
class TodayBoard
  Result = Struct.new(:feedback, :reviews, :upcoming, :offers_pending, :jobs, keyword_init: true)
  JobRow = Struct.new(:id, :title, :status, :openings, :active_count, keyword_init: true)

  def self.call(actor_id:, include_offers: true, include_confidential_jobs: true)
    new(actor_id: actor_id, include_offers: include_offers, include_confidential_jobs: include_confidential_jobs).call
  end

  def initialize(actor_id:, include_offers:, include_confidential_jobs:)
    @actor_id = actor_id
    @include_offers = include_offers
    @include_confidential_jobs = include_confidential_jobs
  end

  def call
    Result.new(
      feedback: feedback,
      reviews: reviews,
      upcoming: upcoming,
      offers_pending: @include_offers ? pending_offers : [],
      jobs: job_rows
    )
  end

  private

  def feedback
    return [] if @actor_id.blank?

    submitted = Scorecard.where(user_id: @actor_id, status: "submitted").select(:interview_id)
    Interview.feedback_open
             .where("JSON_CONTAINS(interviewer_user_ids, ?)", @actor_id.to_json)
             .where.not(id: submitted)
             .includes(:application)
             .order(starts_at: :desc)
             .limit(50)
             .to_a
  end

  def reviews
    ResourceVisibility.applications.where(status: "active").includes(:pipeline).order(created_at: :desc).limit(200).filter_map do |application|
      next unless application.current_stage_key == application.pipeline&.first_stage_key

      application
    end.first(50)
  end

  def upcoming
    Interview.where(status: "scheduled")
             .where(starts_at: Time.current..7.days.from_now)
             .includes(:application)
             .order(:starts_at)
             .limit(20)
             .to_a
  end

  def pending_offers
    Offer.where(status: "pending_approval").includes(:application).order(created_at: :desc).limit(20).to_a
  end

  def job_rows
    scope = Job.where(status: "active").order(:title)
    scope = scope.where(confidential: false) unless @include_confidential_jobs
    jobs = scope.limit(20).to_a
    counts = if jobs.empty?
               {}
    else
               Application.where(status: "active", job_id: jobs.map(&:id)).group(:job_id).count
    end
    jobs.map do |job|
      JobRow.new(
        id: job.id, title: job.title, status: job.status,
        openings: job.openings, active_count: counts[job.id] || 0
      )
    end
  end
end
