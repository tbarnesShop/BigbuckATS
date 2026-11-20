# frozen_string_literal: true

# Who may read which interview feedback. Feedback is written independently, so an interviewer does
# not see the rest of the panel's scorecards for an interview until their own is in.
#
#   scorecard.read_all            every scorecard (owner, admin, recruiter)
#   hiring manager on the job     every scorecard for that job: they make the decision
#   anyone else                   their own, plus the panel's for interviews they have submitted on
#
# All of it stays inside the applications the caller can see (confidential jobs, restricted people).
class ScorecardVisibility
  def self.scope(user_id: Current.actor_id)
    visible = Scorecard.where(interview_id: Interview.where(application_id: ResourceVisibility.applications.select(:id)).select(:id))
    return visible if read_all?

    return visible.none if user_id.blank?

    submitted_on = Scorecard.where(user_id: user_id, status: "submitted").select(:interview_id)
    visible.where(user_id: user_id)
           .or(visible.where(status: "submitted", interview_id: submitted_on))
           .or(visible.where(status: "submitted", interview_id: managed_interviews(user_id)))
  end

  # Corrections: your own scorecard, or anyone's with scorecard.manage.
  def self.editable?(scorecard, user_id: Current.actor_id)
    return true if can?("scorecard.manage")

    can?("scorecard.write") && user_id.present? && scorecard.user_id.to_s == user_id.to_s
  end

  def self.read_all? = can?("scorecard.read_all")

  def self.can?(permission)
    principal = Current.principal
    principal == Principal.legacy || (principal.is_a?(Principal) && principal.can?(permission))
  end

  def self.managed_interviews(user_id)
    jobs = HiringTeam.joins(:members)
                     .where(hiring_team_members: { user_id: user_id, team_role: "hiring-manager" })
                     .select(:job_id)
    Interview.where(application_id: Application.where(job_id: jobs).select(:id)).select(:id)
  end
  private_class_method :managed_interviews
end
