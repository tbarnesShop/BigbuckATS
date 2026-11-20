# frozen_string_literal: true

module Types
  class JobType < Types::BaseObject
    graphql_name "Job"

    # Confidential jobs need job.read_confidential.
    def self.authorized?(object, context)
      super && (!object.confidential || context[:principal]&.can?("job.read_confidential"))
    end

    field :id, ID, null: false
    field :title, String, null: false
    field :status, String, null: false
    field :openings, Integer, null: false
    field :confidential, Boolean, null: false
    field :code_name, String, null: true
    field :version, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :stages, [ Types::StageType ], null: false, description: "The job's resolved pipeline stages, in order"

    field :applications, Types::ApplicationType.connection_type, null: false, permission: "application.read" do
      argument :stage_key, String, required: false
      argument :status, String, required: false
    end

    def stages
      pipeline = load_record(Pipeline, object.pipeline_id)
      Array(pipeline&.resolved_stages)
    end

    def applications(stage_key: nil, status: nil)
      scope = Application.where(job_id: object.id).order(created_at: :desc)
      scope = scope.where(current_stage_key: stage_key) if stage_key
      scope = scope.where(status: status) if status
      scope
    end

    field :custom_fields, [ Types::CustomFieldValueType ], null: false,
                                                        description: "Values of active custom fields you may see, in display order" do
      argument :keys, [ String ], required: false, description: "Only these field keys"
    end

    def custom_fields(keys: nil) = load_custom_fields("job", keys)
  end
end
