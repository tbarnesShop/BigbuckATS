# frozen_string_literal: true

# One schema for every organization (decision 13). Tenant data never changes
# the schema: custom fields are typed values with versioned definitions.
#
# Evolution: changes are additive; a field is marked deprecated before it is
# removed, and CI compares schema.graphql with main to catch breaking changes.
class BigbuckSchema < GraphQL::Schema
  query Types::QueryType
  mutation Types::MutationType

  use GraphQL::Dataloader

  # Custom field value types are only reachable through the CustomFieldValue
  # interface, so they are registered here.
  orphan_types Types::CustomFieldTextValueType, Types::CustomFieldNumberValueType, Types::CustomFieldDateValueType,
               Types::CustomFieldBooleanValueType, Types::CustomFieldOptionValueType,
               Types::CustomFieldOptionsValueType, Types::CustomFieldReferenceValueType

  # Throughput and abuse limits. Browser sessions run persisted queries only;
  # agents and integrations may send their own documents within these limits.
  max_depth 12
  max_complexity 400
  max_query_string_tokens 8_000
  default_page_size 25
  default_max_page_size 100
  validate_timeout 2
  validate_max_errors 20

  AD_HOC_MAX_COMPLEXITY = 200

  rescue_from(ActiveRecord::RecordNotFound) do |_error, _obj, _args, _ctx, field|
    raise GraphQL::ExecutionError.new("#{field&.type&.unwrap&.graphql_name || 'Record'} not found", extensions: { "code" => "not_found" })
  end

  rescue_from(ActiveRecord::RecordInvalid) do |error|
    raise GraphQL::ExecutionError.new(error.record.errors.full_messages.join(", "), extensions: { "code" => "validation_failed" })
  end

  # Objects the caller may not see resolve to null, as if they did not exist.
  def self.unauthorized_object(_error)
    nil
  end

  def self.unauthorized_field(error)
    permission = error.field.respond_to?(:required_permission) ? error.field.required_permission : nil
    raise GraphQL::ExecutionError.new(
      "#{error.type.graphql_name}.#{error.field.graphql_name} needs the #{permission || 'right'} permission.",
      extensions: { "code" => "insufficient_permission", "permission" => permission }.compact
    )
  end
end
