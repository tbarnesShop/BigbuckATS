# frozen_string_literal: true

# Queue scorecard-due nudges: 2 hours after end, then daily for two weeks.
class ScorecardNudge
  def self.due(as_of: Time.current)
    new(as_of: as_of).due
  end

  def initialize(as_of:)
    @as_of = as_of
  end

  def due
    Interview.where(status: %w[scheduled completed])
             .where.not(ends_at: nil)
             .where("ends_at <= ?", @as_of - 2.hours)
             .where("ends_at >= ?", @as_of - 14.days)
             .find_each
             .flat_map { |interview| missing_for(interview) }
  end

  private

  def missing_for(interview)
    Array(interview.interviewer_user_ids).filter_map do |user_id|
      next if Scorecard.exists?(interview_id: interview.id, user_id: user_id, status: "submitted")

      { interview_id: interview.id, user_id: user_id, ends_at: interview.ends_at }
    end
  end
end
