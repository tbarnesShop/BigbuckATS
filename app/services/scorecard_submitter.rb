# frozen_string_literal: true

# Writes interview feedback. A scorecard belongs to one interviewer on one interview:
#
#   submit   the interviewer writes (or rewrites) their own. They must be on the interview's panel,
#            and the interview must have started.
#   revise   an editor changes a scorecard that already exists: its author, or anyone holding
#            scorecard.manage. Authorship never moves; the audit row names who made the change.
#
# When the interview's pipeline definition names a rubric (`rubric_key`), every required rubric
# attribute must be rated either way.
class ScorecardSubmitter
  RATINGS = %w[strong_yes yes mixed no].freeze

  def self.call(interview:, user:, rating:, notes: nil, attribute_ratings: nil)
    new(interview: interview, rating: rating, notes: notes, attribute_ratings: attribute_ratings).submit(user)
  end

  def self.revise(scorecard:, rating:, notes: nil, attribute_ratings: nil)
    new(interview: scorecard.interview, rating: rating, notes: notes, attribute_ratings: attribute_ratings)
      .revise(scorecard)
  end

  def initialize(interview:, rating:, notes: nil, attribute_ratings: nil)
    @interview = interview
    @rating = rating.to_s
    @notes = notes
    @attribute_ratings = (attribute_ratings || {}).to_h.deep_stringify_keys
  end

  def submit(user)
    ActiveRecord::Base.transaction do
      require_interviewer!(user)
      require_started!
      require_rubric!
      scorecard = Scorecard.find_or_initialize_by(
        organization_id: Current.organization_id,
        interview_id: @interview.id,
        user_id: user.id
      )
      was = scorecard.status_in_database || "draft"
      write!(scorecard, action: was == "submitted" ? "scorecard.updated" : "scorecard.submitted", was: was)
    end
  end

  def revise(scorecard)
    ActiveRecord::Base.transaction do
      require_rubric!
      write!(scorecard, action: "scorecard.updated", was: scorecard.status)
    end
  end

  private

  def write!(scorecard, action:, was:)
    scorecard.assign_attributes(
      rating: @rating,
      notes: @notes,
      attribute_ratings: @attribute_ratings.presence,
      status: "submitted"
    )
    changes = scorecard.changes.except("status", "organization_id", "interview_id", "user_id")
    changes["status"] = [ was, "submitted" ] unless was == "submitted"
    ChangeWriter.call(
      record: scorecard,
      action: action,
      event_type: action,
      payload: { "interview_id" => @interview.id, "rating" => @rating, "author_user_id" => scorecard.user_id },
      changes: changes
    )
    scorecard
  end

  # Feedback is assigned: only the people booked onto the interview may write it. An interview with
  # nobody assigned accepts none, so a form never opens for the whole team.
  def require_interviewer!(user)
    panel = Array(@interview.interviewer_user_ids).map(&:to_s)
    raise ArgumentError, "interview_unassigned" if panel.empty?
    raise ArgumentError, "not_an_interviewer" unless panel.include?(user.id.to_s)
  end

  # Feedback describes an interview that happened, so it opens when the interview starts, and an
  # interview nobody has put on the calendar yet takes none. Shared demo sandboxes relax the first
  # half only: a visitor books next week's interview and wants to finish the hire in one sitting, so
  # there a booked interview accepts its scorecard early and the UI marks it as written beforehand.
  def require_started!
    return if @interview.status == "completed"

    starts_at = @interview.starts_at
    raise ArgumentError, "interview_not_scheduled" if starts_at.blank? || @interview.status == "requested"
    return if starts_at <= Time.current
    return if DemoSandbox.for_organization(Current.organization_id)

    raise ArgumentError, "feedback_before_interview"
  end

  def require_rubric!
    raise ArgumentError, "invalid_rating" unless RATINGS.include?(@rating)

    key = rubric_key
    return if key.blank?

    rubric = ScorecardRubric.find_by(key: key)
    raise ArgumentError, "rubric_not_found:#{key}" unless rubric

    missing = rubric.required_keys.reject { |attribute| @attribute_ratings[attribute].present? }
    raise ArgumentError, "rubric_incomplete:#{missing.join(",")}" if missing.any?
  end

  def rubric_key
    stages = Array(@interview.application&.pipeline&.resolved_stages)
    stage = stages.find { |row| row["key"] == @interview.stage_key }
    definition = Array(stage && stage["interviews"]).find { |row| row["key"] == @interview.interview_key }
    definition && definition["rubric_key"]
  end
end
