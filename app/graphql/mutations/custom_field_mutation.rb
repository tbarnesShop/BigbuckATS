# frozen_string_literal: true

module Mutations
  # Shared error mapping for custom field commands.
  class CustomFieldMutation < BaseMutation
    private

    def guarded(field_name = :field)
      yield
    rescue CustomFieldDefinitions::Error => e
      { field_name => nil, user_errors: [ user_error(e.code, e.message) ] }
    rescue ActiveRecord::RecordInvalid => e
      { field_name => nil, user_errors: [ user_error("validation_failed", e.record.errors.full_messages.join(", ")) ] }
    end
  end
end
