# frozen_string_literal: true

module Mutations
  class UpdateApplicationForm < BaseMutation
    description "Set required standard fields and, when sent, which application fields are screening questions."
    permission "settings.manage"

    argument :required_fields, [ String ], required: true
    argument :screening_field_ids, [ ID ], required: false,
                                         description: "Full set of application fields to show on apply. Omit to leave flags alone."

    field :application_form, Types::ApplicationFormType, null: true

    def resolve(required_fields:, screening_field_ids: nil)
      org = Organization.find(Current.organization_id)
      ApplicationFormSettings.update!(org, required_fields: required_fields, screening_field_ids: screening_field_ids)
      { application_form: ApplicationFormSettings.payload(org.reload, principal: principal), user_errors: [] }
    rescue ArgumentError => e
      { application_form: nil, user_errors: [ user_error("invalid_application_form", e.message) ] }
    end
  end
end
