# frozen_string_literal: true

# Permission vocabulary and the system role presets. A principal's effective
# permissions come from its role (users), intersected with credential or agent
# scopes (see Scopes), so an agent can never do more than the user who owns it.
module Permissions
  ALL = %w[
    person.read person.read_restricted person.create person.update person.edit_details person.merge
    person.export person.erase company.manage document.upload document.read
    role.manage dimension.manage custom_field.manage audit.read
    job.read_confidential project.read_confidential
    job.read job.manage application.read application.create application.move_stage
    offer.read offer.create offer.send offer.rescind offer.approve offer.view_compensation
    interview.schedule scorecard.write scorecard.read_all scorecard.manage project.read project.manage
    sequence.read sequence.manage sequence.enroll communication.send mailbox.read
    mailbox.connect mailbox.manage webhook.manage import.manage config.plan config.apply
    settings.manage compliance.manage agent.manage_own agent.manage integration.manage
    requisition.read requisition.manage referral.create referral.read analytics.read
  ].freeze

  OWNER = ALL

  ADMIN = %w[
    person.read person.read_restricted person.create person.update person.edit_details person.merge
    company.manage document.upload document.read dimension.manage custom_field.manage
    job.read job.manage application.read application.create application.move_stage
    offer.read offer.create offer.send offer.rescind offer.approve interview.schedule
    scorecard.write scorecard.read_all scorecard.manage project.read project.manage sequence.read
    sequence.manage sequence.enroll communication.send mailbox.read mailbox.connect
    mailbox.manage webhook.manage import.manage config.plan settings.manage agent.manage_own
    requisition.read requisition.manage referral.create referral.read analytics.read
  ].freeze

  RECRUITER = %w[
    person.read person.create person.update person.edit_details company.manage document.upload document.read
    job.read job.manage application.read application.create application.move_stage
    offer.read offer.create offer.send offer.approve offer.view_compensation interview.schedule scorecard.write
    scorecard.read_all project.read project.manage sequence.read sequence.manage sequence.enroll
    communication.send mailbox.read mailbox.connect agent.manage_own
    requisition.read referral.create referral.read analytics.read
  ].freeze

  # Feedback: everyone here can write their own scorecard on an interview they are assigned to
  # (scorecard.write). Recruiters and up read every scorecard (scorecard.read_all); only owners and
  # admins may correct someone else's (scorecard.manage).
  #
  # Hiring managers can view public people in their scoped teams; no create/merge/restricted.
  HIRING_MANAGER = %w[
    person.read person.edit_details document.read document.upload job.read application.read scorecard.write offer.read
    offer.approve agent.manage_own referral.create referral.read
  ].freeze

  PRESETS = {
    "owner" => OWNER,
    "admin" => ADMIN,
    "recruiter" => RECRUITER,
    "hiring_manager" => HIRING_MANAGER
  }.freeze
end
