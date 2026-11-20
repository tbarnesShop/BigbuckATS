# frozen_string_literal: true

module Mutations
  class ComplianceMutation < BaseMutation
    private

    def guarded(field_name)
      yield
    rescue ComplianceDesk::Error => e
      { field_name => nil, user_errors: [ user_error(e.code, e.message) ] }
    rescue ActiveRecord::RecordInvalid => e
      { field_name => nil, user_errors: [ user_error("validation_failed", e.record.errors.full_messages.join(", ")) ] }
    end

    def visible_person(id)
      person = Person.find_by(id: id)
      person if person && PersonVisibility.visible?(person, viewer: context[:viewer])
    end
  end
end
