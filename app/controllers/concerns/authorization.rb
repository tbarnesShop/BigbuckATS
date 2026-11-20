# frozen_string_literal: true

# Declares which permission each API action needs and checks it against the
# authenticated principal. Actions listed in PUBLIC need no credential; any
# other unlisted action only needs an authenticated member of the organization.
module Authorization
  extend ActiveSupport::Concern

  PUBLIC = %w[
    v1/health#show
    v1/sessions#create v1/sessions#exchange v1/sessions#demo_memberships
    v1/organizations#create
    v1/careers#public_show
    v1/careers#public_apply
    v1/offers#public_show v1/offers#public_accept v1/offers#public_decline
    v1/scheduling#public_show v1/scheduling#public_book
    v1/unsubscribe#show v1/unsubscribe#create
    v1/oauth/google#start v1/oauth/google#callback v1/oauth/google#status
  ].freeze

  ACTION_PERMISSIONS = {
    "v1/oauth_identities#index" => "integration.manage",
    "v1/oauth_identities#create" => "integration.manage",
    "v1/oauth_identities#revoke" => "integration.manage",
    "v1/postings#index" => "job.read",
    "v1/postings#create" => "job.manage",
    "v1/postings#update" => "job.manage",
    "v1/application_question_templates#index" => "job.read",
    "v1/application_question_templates#create" => "job.manage",
    "v1/application_question_templates#update" => "job.manage",
    "v1/people#index" => "person.read",
    "v1/documents#index" => "document.read",
    "v1/documents#create" => "document.upload",
    "v1/documents#show" => "document.read",
    "v1/people#show" => "person.read",
    "v1/people#timeline" => "person.read",
    "v1/people#feed" => "person.read",
    "v1/people#preview_message" => "person.read",
    "v1/people#list_communications" => "person.read",
    "v1/people#create" => "person.create",
    "v1/people#update" => "person.update",
    "v1/people#bulk" => "person.update",
    "v1/people#create_communication" => "communication.send",
    "v1/people#erase" => "person.erase",
    "v1/tasks#index" => "person.read",
    "v1/tasks#create" => "person.update",
    "v1/tasks#update" => "person.update",
    "v1/tasks#complete" => "person.update",
    "v1/tasks#cancel" => "person.update",
    "v1/notes#index" => "person.read",
    "v1/notes#create" => "person.update",
    "v1/notes#update" => "person.update",
    "v1/notes#destroy" => "person.update",
    "v1/tags#index" => "person.read",
    "v1/tags#person_index" => "person.read",
    "v1/tags#create" => "person.update",
    "v1/tags#update" => "person.update",
    "v1/tags#merge" => "person.update",
    "v1/tags#person_add" => "person.update",
    "v1/tags#person_remove" => "person.update",
    "v1/saved_searches#index" => "person.read",
    "v1/saved_searches#create" => "person.read",
    "v1/saved_searches#destroy" => "person.read",
    "v1/saved_searches#update" => "person.read",
    "v1/saved_searches#people" => "person.read",
    "v1/jobs#rediscovery" => "person.read",
    "v1/rediscovery#criteria" => "job.read",
    "v1/rediscovery#update_criteria" => "job.manage",
    "v1/rediscovery#run" => "project.manage",
    "v1/rediscovery#queue" => "person.read",
    "v1/rediscovery#review" => "project.manage",
    "v1/sourcing_agent#run" => "project.manage",
    "v1/agent_proposals#index" => "project.read",
    "v1/agent_proposals#approve" => "sequence.enroll",
    "v1/agent_proposals#reject" => "sequence.enroll",
    "v1/agent_proposals#bulk_approve" => "sequence.enroll",
    "v1/sequences#bulk_enroll" => "sequence.enroll",
    "v1/sequences#enroll_planned" => "sequence.enroll",
    "v1/sequences#enrollment_plan" => "sequence.read",
    "v1/analytics#funnel" => "analytics.read",
    "v1/analytics#sourcing" => "analytics.read",
    "v1/analytics#outreach" => "analytics.read",
    "v1/analytics#outreach_snapshots" => "analytics.read",
    "v1/communications#update" => "communication.send",
    "v1/dnc_companies#index" => "company.manage",
    "v1/dnc_companies#create" => "company.manage",
    "v1/dnc_companies#destroy" => "company.manage",
    "v1/referrals#index" => "referral.read",
    "v1/referrals#show" => "referral.read",
    "v1/referrals#create" => "referral.create",
    "v1/requisitions#index" => "requisition.read",
    "v1/requisitions#show" => "requisition.read",
    "v1/requisitions#create" => "requisition.manage",
    "v1/requisitions#open_req" => "requisition.manage",
    "v1/requisitions#close" => "requisition.manage",
    "v1/sourcing_tasks#index" => "sequence.read",
    "v1/sourcing_tasks#complete" => "sequence.enroll",
    "v1/companies#index" => "person.read",
    "v1/companies#show" => "person.read",
    "v1/companies#create" => "company.manage",
    "v1/affiliations#index" => "person.read",
    "v1/affiliations#create" => "company.manage",
    "v1/jobs#index" => "job.read",
    "v1/jobs#show" => "job.read",
    "v1/jobs#create" => "job.manage",
    "v1/jobs#form_options" => "job.manage",
    "v1/jobs#update" => "job.manage",
    "v1/jobs#add_team_member" => "job.manage",
    "v1/jobs#update_team_member" => "job.manage",
    "v1/jobs#remove_team_member" => "job.manage",
    "v1/jobs#update_pipeline" => "job.manage",
    "v1/projects#index" => "project.read",
    "v1/projects#show" => "project.read",
    "v1/projects#members" => "project.read",
    "v1/projects#create" => "project.manage",
    "v1/projects#create_member" => "project.manage",
    "v1/projects#update" => "project.manage",
    "v1/projects#add_people" => "project.manage",
    "v1/projects#add_from_job" => "project.manage",
    "v1/projects#bulk_transition" => "project.manage",
    "v1/project_members#update" => "project.manage",
    "v1/project_members#index" => "project.read",
    "v1/project_members#show" => "project.read",
    "v1/project_members#transitions" => "project.read",
    "v1/project_members#create_transition" => "project.manage",
    "v1/project_members#convert" => "project.manage",
    "v1/sequences#index" => "sequence.read",
    "v1/sequences#show" => "sequence.read",
    "v1/sequences#enrollments" => "sequence.read",
    "v1/sequences#create" => "sequence.manage",
    "v1/sequences#update" => "sequence.manage",
    "v1/sequences#preview" => "sequence.read",
    "v1/sequences#stats" => "sequence.read",
    "v1/sequences#create_enrollment" => "sequence.enroll",
    "v1/enrollments#index" => "sequence.read",
    "v1/enrollments#show" => "sequence.read",
    "v1/enrollments#stop" => "sequence.enroll",
    "v1/mailboxes#index" => "mailbox.read",
    "v1/mailboxes#create" => "mailbox.connect",
    "v1/mailboxes#update" => "mailbox.manage",
    "v1/mailboxes#inbound" => "mailbox.manage",
    "v1/mailboxes#messages" => "mailbox.read",
    "v1/mailboxes#simulate" => "mailbox.manage",
    "v1/scorecards#index" => "application.read",
    "v1/scorecards#create" => "scorecard.write",
    # Own scorecard with scorecard.write, anyone's with scorecard.manage: checked in the action.
    "v1/scorecards#update" => "application.read",
    "v1/compliance_policies#index" => "compliance.manage",
    "v1/compliance_policies#show" => "compliance.manage",
    "v1/webhooks#index" => "webhook.manage",
    "v1/webhooks#create" => "webhook.manage",
    "v1/webhooks#update" => "webhook.manage",
    "v1/webhooks#rotate_secret" => "webhook.manage",
    "v1/webhooks#drain" => "webhook.manage",
    "v1/events#index" => "audit.read",
    "v1/events#sync_people" => "person.read",
    "v1/config#plans" => "config.plan",
    "v1/config#plan" => "config.plan",
    "v1/config#apply" => "config.apply",
    "v1/imports#index" => "import.manage",
    "v1/imports#show" => "import.manage",
    "v1/imports#create" => "import.manage",
    "v1/applications#index" => "application.read",
    "v1/applications#show" => "application.read",
    "v1/applications#transitions" => "application.read",
    "v1/applications#interviews" => "application.read",
    "v1/applications#missing_feedback" => "application.read",
    "v1/applications#create" => "application.create",
    "v1/applications#create_transition" => "application.move_stage",
    "v1/applications#create_offer" => "offer.create",
    "v1/applications#create_scheduling_link" => "interview.schedule",
    "v1/applications#create_booking" => "interview.schedule",
    "v1/applications#booking_options" => "interview.schedule",
    "v1/offers#index" => "offer.read",
    "v1/offers#show" => "offer.read",
    "v1/offers#submit" => "offer.create",
    "v1/offers#approve" => "offer.approve",
    "v1/offers#send_letter" => "offer.send",
    "v1/offers#resend" => "offer.send",
    "v1/offers#record_response" => "offer.send",
    "v1/offers#update_checklist" => "offer.create",
    "v1/offers#rescind" => "offer.rescind",
    "v1/message_templates#index" => "sequence.read",
    "v1/message_templates#create" => "sequence.manage",
    "v1/message_templates#update" => "sequence.manage",
    "v1/message_templates#archive" => "sequence.manage",
    "v1/application_form#show" => "job.read",
    "v1/application_form#update" => "settings.manage",
    "v1/today#show" => "application.read",
    "v1/calendar_connections#index" => "interview.schedule",
    "v1/calendar_connections#create" => "interview.schedule",
    "v1/scorecard_rubrics#index" => "application.read",
    "v1/scorecard_rubrics#create" => "settings.manage",
    "v1/scorecard_rubrics#update" => "settings.manage",
    "v1/interviews#index" => "application.read",
    "v1/interviews#show" => "application.read",
    "v1/interviews#awaiting_schedule" => "application.read",
    "v1/team#index" => "job.read",
    "v1/interviews#cancel" => "interview.schedule",
    "v1/interviews#reschedule" => "interview.schedule",
    "v1/organizations#update" => "settings.manage",
    "v1/agents#create" => "agent.manage_own",
    "v1/custom_fields#create" => "custom_field.manage",
    "v1/custom_fields#update" => "custom_field.manage",
    "v1/custom_fields#archive" => "custom_field.manage",
    "v1/custom_fields#restore" => "custom_field.manage",
    "v1/custom_fields#type_change" => "custom_field.manage",
    "v1/compliance#data_requests" => "compliance.manage",
    "v1/compliance#create_data_request" => "compliance.manage",
    "v1/compliance#complete_data_request" => "compliance.manage",
    "v1/compliance#reject_data_request" => "compliance.manage",
    "v1/compliance#access_packet" => "person.export",
    "v1/compliance#consents" => "person.read",
    "v1/compliance#record_consent" => "compliance.manage",
    "v1/compliance#legal_holds" => "compliance.manage",
    "v1/compliance#create_legal_hold" => "compliance.manage",
    "v1/compliance#release_legal_hold" => "compliance.manage"
  }.freeze

  included do
    rescue_from Authenticator::Unauthenticated do |error|
      render_problem(status: :unauthorized, code: error.code, title: error.message)
    end
    rescue_from Authenticator::Forbidden do |error|
      render_problem(status: :forbidden, code: error.code, title: error.message)
    end
  end

  class InsufficientPermission < StandardError
    attr_reader :permission

    def initialize(permission)
      @permission = permission
      super("This action needs the #{permission} permission.")
    end
  end

  private

  def action_key
    "#{controller_path}##{action_name}"
  end

  def public_action?
    PUBLIC.include?(action_key)
  end

  def legacy_principal?
    Current.principal == Principal.legacy
  end

  def current_principal
    Current.principal.is_a?(Principal) ? Current.principal : nil
  end

  def authorize_action!
    return if public_action? || legacy_principal?

    unless current_principal
      raise Authenticator::Unauthenticated.new("unauthenticated", "Send a bearer token: Authorization: Bearer <token>.")
    end

    permission = ACTION_PERMISSIONS[action_key]
    return if action_key == "v1/people#update" && current_principal.can?("person.edit_details")
    require_permission!(permission) if permission
  end

  # For checks inside an action (e.g. managing someone else's agent).
  def require_permission!(permission)
    return if legacy_principal?
    raise InsufficientPermission, permission unless current_principal&.can?(permission)
  end

  def permitted?(permission)
    legacy_principal? || current_principal&.can?(permission)
  end
end
