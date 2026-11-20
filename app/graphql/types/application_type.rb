# frozen_string_literal: true

module Types
  class ApplicationType < Types::BaseObject
    graphql_name "Application"

    def self.authorized?(object, context)
      super && context[:principal]&.can?("application.read") &&
        PersonVisibility.visible?(object.person, viewer: context[:viewer]) &&
        (!object.job.confidential || context[:principal]&.can?("job.read_confidential"))
    end

    field :id, ID, null: false
    field :status, String, null: false
    field :current_stage_key, String, null: false
    field :pipeline_version, Integer, null: false
    field :version, Integer, null: false, description: "Pass as expectedVersion to mutations"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :person, Types::PersonType, null: true, description: "Null when the caller may not see this person"
    field :job, Types::JobType, null: true, description: "Null when the job is confidential to the caller"
    field :stages, [ Types::StageType ], null: false
    field :transitions, [ Types::StageTransitionType ], null: false, description: "Stage history, oldest first"

    field :upcoming_interview, Types::InterviewType, null: true,
                                                     description: "The next scheduled interview from today on, if any"

    def upcoming_interview = dataloader.with(Sources::UpcomingInterviews).load(object.id)

    def person = load_record(Person, object.person_id)
    def job = load_record(Job, object.job_id)

    def stages
      Array(load_record(Pipeline, object.pipeline_id)&.resolved_stages)
    end

    def transitions
      StageTransition.where(subject_type: "Application", subject_id: object.id).order(:created_at)
    end

    field :custom_fields, [ Types::CustomFieldValueType ], null: false,
                                                        description: "Values of active custom fields you may see, in display order" do
      argument :keys, [ String ], required: false, description: "Only these field keys"
    end

    def custom_fields(keys: nil) = load_custom_fields("application", keys)
  end
end
