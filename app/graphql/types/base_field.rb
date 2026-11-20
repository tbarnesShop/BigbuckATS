# frozen_string_literal: true

module Types
  # `field :x, ..., permission: "offer.view_compensation"` hides a field from
  # principals without that permission (an error names the permission).
  class BaseField < GraphQL::Schema::Field
    argument_class Types::BaseArgument

    attr_reader :required_permission

    def initialize(*args, permission: nil, **kwargs, &block)
      @required_permission = permission
      super(*args, **kwargs, &block)
    end

    def authorized?(obj, args, ctx)
      super && (required_permission.nil? || ctx[:principal]&.can?(required_permission))
    end
  end
end
