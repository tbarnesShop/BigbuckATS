# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    graphql_name "Query"

    field :viewer, Types::ViewerType, null: false, description: "Who is calling and what they may do"

    field :person, Types::PersonType, null: true, permission: "person.read" do
      argument :id, ID, required: true
    end

    field :people, Types::PersonType.connection_type, null: false, permission: "person.read",
                                                       description: "People the caller may see, newest first" do
      argument :lifecycle_stage, String, required: false
    end

    field :job, Types::JobType, null: true, permission: "job.read" do
      argument :id, ID, required: true
    end

    field :jobs, Types::JobType.connection_type, null: false, permission: "job.read" do
      argument :status, String, required: false
    end

    field :application, Types::ApplicationType, null: true, permission: "application.read" do
      argument :id, ID, required: true
    end

    field :applications, Types::ApplicationType.connection_type, null: false, permission: "application.read" do
      argument :job_id, ID, required: false
      argument :person_id, ID, required: false
      argument :stage_key, String, required: false
      argument :status, String, required: false
    end

    field :agents, [ Types::AgentType ], null: false, description: "Your agents (everyone's with agent.manage)"

    field :data_requests, Types::DataRequestType.connection_type, null: false, permission: "compliance.manage",
                                                                    description: "Data-subject requests, soonest due first" do
      argument :status, String, required: false
    end

    field :legal_holds, [ Types::LegalHoldType ], null: false, permission: "compliance.manage" do
      argument :active, Boolean, required: false, default_value: true
    end

    field :today, Types::TodayType, null: false, permission: "application.read",
                                    description: "Feedback owed, new applicants, this week's interviews, pending offers, active jobs"

    field :interviews, [ Types::InterviewType ], null: false, permission: "application.read",
                                               description: "Interviews across jobs. tab: upcoming, schedule, feedback, mine. " \
                                                            "scope: mine (my panels and my hiring-team jobs) or all" do
      argument :scope, String, required: false
      argument :tab, String, required: false
    end

    field :offers, Types::OfferListType, null: false, permission: "offer.read",
                                         description: "Offers, with counts by status" do
      argument :application_id, ID, required: false
      argument :status, String, required: false
    end

    field :calendar_connections, [ Types::ConnectedCalendarType ], null: false, permission: "interview.schedule", connection: false

    field :scorecard_rubrics, [ Types::ScorecardRubricType ], null: false, permission: "application.read"

    field :application_form, Types::ApplicationFormType, null: false, permission: "job.read"

    field :message_templates, [ Types::MessageTemplateType ], null: false, permission: "sequence.read",
                                                            description: "status: active (default), archived, or all" do
      argument :status, String, required: false
    end

    field :custom_field_definitions, [ Types::CustomFieldDefinitionType ], null: false,
                                                                         description: "Field definitions for one kind of record" do
      argument :entity, String, required: true, description: "person, job, application, offer, project or company"
      argument :include_archived, Boolean, required: false, default_value: false
    end

    field :custom_field_type_change_preview, Types::CustomFieldTypeChangePreviewType, null: false,
                                                                                     permission: "custom_field.manage",
                                                                                     description: "What changing a field's type would do to stored values" do
      argument :id, ID, required: true
      argument :to_type, String, required: true
      argument :options, [ Types::CustomFieldOptionInput ], required: false
    end

    def viewer = principal

    def person(id:) = Person.find_by(id: id)

    def people(lifecycle_stage: nil)
      scope = PersonVisibility.scope_for(person_viewer).order(created_at: :desc)
      lifecycle_stage ? scope.where(lifecycle_stage: lifecycle_stage) : scope
    end

    def job(id:) = Job.find_by(id: id)

    def jobs(status: nil)
      scope = Job.order(created_at: :desc)
      scope = scope.where(confidential: false) unless principal.can?("job.read_confidential")
      status ? scope.where(status: status) : scope
    end

    def application(id:) = ResourceVisibility.applications.find_by(id: id)

    def applications(job_id: nil, person_id: nil, stage_key: nil, status: nil)
      scope = ResourceVisibility.applications.order(created_at: :desc)
      scope = scope.where(job_id: job_id) if job_id
      scope = scope.where(person_id: person_id) if person_id
      scope = scope.where(current_stage_key: stage_key) if stage_key
      scope = scope.where(status: status) if status
      scope
    end

    def custom_field_definitions(entity:, include_archived:)
      scope = CustomField.where(entity: entity).order(:display_order, :key)
      scope = scope.where(status: "active") unless include_archived
      scope.to_a.select { |f| f.visible_to?(principal) }
    end

    def custom_field_type_change_preview(id:, to_type:, options: nil)
      CustomFieldDefinitions.preview_type_change(CustomField.find(id), to_type: to_type, options: options&.map(&:to_h))
    rescue CustomFieldDefinitions::Error => e
      raise GraphQL::ExecutionError.new(e.message, extensions: { "code" => e.code })
    end

    def data_requests(status: nil)
      scope = DataRequest.order(:due_at)
      status ? scope.where(status: status) : scope
    end

    def legal_holds(active:)
      scope = LegalHold.order(placed_at: :desc)
      active ? scope.active.to_a : scope.limit(500).to_a
    end

    def agents
      return Agent.order(:created_at) if principal.can?("agent.manage")
      return Agent.none unless principal.membership

      Agent.where(owner_membership_id: principal.membership.id).order(:created_at)
    end

    def today
      TodayBoard.call(
        actor_id: principal.user_id,
        include_offers: principal.can?("offer.read"),
        include_confidential_jobs: principal.can?("job.read_confidential")
      )
    end

    def interviews(tab: nil, scope: nil)
      InterviewHub.list(tab: tab, scope: scope, actor_id: principal.user_id).to_a
    rescue ArgumentError => e
      raise GraphQL::ExecutionError.new(e.message, extensions: { "code" => "invalid_interview" })
    end

    def offers(application_id: nil, status: nil)
      listed = OfferIndex.call(application_id: application_id, status: status)
      {
        "counts" => listed[:counts].map { |key, total| { "status" => key, "count" => total } },
        "nodes" => listed[:rows]
      }
    rescue ArgumentError => e
      raise GraphQL::ExecutionError.new(e.message, extensions: { "code" => "invalid_filter" })
    end

    def calendar_connections
      CalendarConnection.order(:created_at).limit(100).to_a
    end

    def scorecard_rubrics
      ScorecardRubric.order(:key).limit(100).to_a
    end

    def application_form
      ApplicationFormSettings.payload(Organization.find(Current.organization_id), principal: principal)
    end

    def message_templates(status: nil)
      status = status.presence || "active"
      unless MessageTemplate::STATUSES.include?(status)
        raise GraphQL::ExecutionError.new("unknown_status:#{status}", extensions: { "code" => "invalid_message_template" })
      end

      rows = MessageTemplate.order(:key, :locale)
      rows = rows.active if status == "active"
      rows = rows.archived if status == "archived"
      rows.limit(200).to_a
    end
  end
end
