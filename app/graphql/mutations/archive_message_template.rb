# frozen_string_literal: true

module Mutations
  class ArchiveMessageTemplate < BaseMutation
    description "Archive a message template. Sequences that already use it keep rendering it."
    permission "sequence.manage"

    argument :id, ID, required: true

    field :template, Types::MessageTemplateType, null: true

    def resolve(id:)
      template = MessageTemplate.find(id)
      template.archive_template!
      { template: template, user_errors: [] }
    rescue ArgumentError => e
      { template: nil, user_errors: [ user_error(e.message, e.message) ] }
    end
  end
end
