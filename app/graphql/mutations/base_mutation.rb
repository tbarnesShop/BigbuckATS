# frozen_string_literal: true

module Mutations
  # Command mutations. Each declares the permission it needs, takes
  # `expectedVersion` for optimistic locking where it changes a versioned
  # record, and returns `userErrors` for problems the caller can fix.
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    argument_class Types::BaseArgument
    field_class Types::BaseField
    input_object_class Types::BaseInputObject
    object_class Types::BaseObject

    field :user_errors, [ Types::UserErrorType ], null: false

    class << self
      attr_reader :required_permission

      def permission(name)
        @required_permission = name
      end
    end

    # Runs after arguments load, before resolve (graphql-ruby Resolver#authorized?).
    def authorized?(**inputs)
      if DemoSandbox.for_organization(Current.organization_id) && DemoPolicy.blocked?(action: self.class.graphql_name, values: inputs)
        raise GraphQL::ExecutionError.new(DemoPolicy::MESSAGE, extensions: { "code" => "demo_action_blocked" })
      end
      permission = self.class.required_permission
      if permission && !context[:principal]&.can?(permission)
        raise GraphQL::ExecutionError.new(
          "This action needs the #{permission} permission.",
          extensions: { "code" => "insufficient_permission", "permission" => permission }
        )
      end

      super
    end

    private

    def user_error(code, message, path: nil)
      { code: code, message: message, path: path }
    end

    def principal
      context[:principal]
    end

    # Locks the row and checks the caller saw the latest version.
    def lock_with_version!(model, id, expected_version)
      scope = case model.name
      when "Application" then ResourceVisibility.applications
      when "Person" then ResourceVisibility.people
      when "Job" then ResourceVisibility.jobs
      when "Project" then ResourceVisibility.projects
      when "ProjectMember" then ResourceVisibility.members
      when "Offer" then ResourceVisibility.offers
      else model
      end
      record = scope.lock.find_by(id: id)
      return [ nil, user_error("not_found", "#{model.model_name.human} not found", path: [ "id" ]) ] unless record
      if expected_version && record.version != expected_version
        return [ nil, user_error("stale_version",
                                "#{model.model_name.human} is at version #{record.version}, not #{expected_version}. Reload and retry.",
                                path: [ "expectedVersion" ]) ]
      end

      [ record, nil ]
    end
  end
end
