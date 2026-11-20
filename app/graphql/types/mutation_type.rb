# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    graphql_name "Mutation"

    field :move_application_stage, mutation: Mutations::MoveApplicationStage
    field :reject_application, mutation: Mutations::RejectApplication

    field :connect_calendar, mutation: Mutations::ConnectCalendar
    field :create_scorecard_rubric, mutation: Mutations::CreateScorecardRubric
    field :update_application_form, mutation: Mutations::UpdateApplicationForm
    field :create_message_template, mutation: Mutations::CreateMessageTemplate
    field :archive_message_template, mutation: Mutations::ArchiveMessageTemplate

    field :create_custom_field, mutation: Mutations::CreateCustomField
    field :update_custom_field, mutation: Mutations::UpdateCustomField
    field :archive_custom_field, mutation: Mutations::ArchiveCustomField
    field :change_custom_field_type, mutation: Mutations::ChangeCustomFieldType
    field :set_custom_field_value, mutation: Mutations::SetCustomFieldValue

    field :open_data_request, mutation: Mutations::OpenDataRequest
    field :complete_data_request, mutation: Mutations::CompleteDataRequest
    field :record_consent, mutation: Mutations::RecordConsent
    field :place_legal_hold, mutation: Mutations::PlaceLegalHold
    field :release_legal_hold, mutation: Mutations::ReleaseLegalHold
  end
end
