# frozen_string_literal: true

# Shared query boundaries for REST and GraphQL. The header harness is only
# available in development/test; authenticated callers always use their scopes.
class ResourceVisibility
  def self.viewer
    principal = Current.principal
    return PrincipalViewer.new(principal) if principal.is_a?(Principal)
    Membership.find_by(user_id: Current.actor_id, status: "active")
  end

  def self.legacy? = Current.principal == Principal.legacy
  def self.people = legacy? && viewer.nil? ? Person.visible_catalog : PersonVisibility.scope_for(viewer)
  def self.jobs
    legacy? || Current.principal&.can?("job.read_confidential") ? Job.all : Job.where(confidential: false)
  end
  # Applications on visible people, plus any the caller is booked to interview on: feedback assigned
  # to someone must let them open the candidate, even outside their person scope.
  def self.applications
    in_jobs = Application.where(job_id: jobs.select(:id))
    visible = in_jobs.where(person_id: people.select(:id))
    return visible if legacy? && viewer.nil?

    visible.or(in_jobs.where(id: PersonVisibility.interviewing_application_ids(viewer)))
  end
  def self.projects
    scope = Project.where(job_id: nil).or(Project.where(job_id: jobs.select(:id)))
    legacy? || Current.principal&.can?("project.read_confidential") ? scope : scope.where(confidential: false)
  end
  def self.members = ProjectMember.where(person_id: people.select(:id), project_id: projects.select(:id))
  def self.referrals
    Referral.where(person_id: people.select(:id)).where(job_id: nil).or(
      Referral.where(person_id: people.select(:id), job_id: jobs.select(:id)))
  end
  # Offers on visible applications, plus any offer whose approval is assigned to the caller: a policy that
  # names someone as approver must let them read what they are approving, even outside their person scope.
  def self.offers
    visible = Offer.where(application_id: applications.select(:id))
    return visible if Current.actor_id.blank? || Current.agent_id.present?
    visible.or(Offer.where(id: Approval.where(entity_type: "Offer", approver_user_id: Current.actor_id).select(:entity_id)))
  end
end
