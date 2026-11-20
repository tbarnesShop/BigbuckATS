# frozen_string_literal: true

module Mutations
  class CreateMessageTemplate < BaseMutation
    description "Create a message template. Locale defaults to en."
    permission "sequence.manage"

    argument :key, String, required: true
    argument :message_type, String, required: true
    argument :subject, String, required: true
    argument :body, String, required: true
    argument :locale, String, required: false

    field :template, Types::MessageTemplateType, null: true

    def resolve(key:, message_type:, subject:, body:, locale: nil)
      template = MessageTemplate.create_template!(
        key: key, message_type: message_type, subject: subject, body: body, locale: locale
      )
      { template: template, user_errors: [] }
    rescue ArgumentError => e
      { template: nil, user_errors: [ user_error(e.message, e.message) ] }
    rescue ActiveRecord::RecordInvalid => e
      { template: nil, user_errors: [ user_error("validation_failed", e.record.errors.full_messages.join(", ")) ] }
    end
  end
end
