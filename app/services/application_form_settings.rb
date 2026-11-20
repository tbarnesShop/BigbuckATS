# frozen_string_literal: true

# Careers application form: which standard fields are required, and which
# application custom fields are screening questions (`show_on_apply`).
class ApplicationFormSettings
  DEFAULT_REQUIRED = %w[display_name email].freeze
  STANDARD_FIELDS = %w[display_name email phone linkedin links country region].freeze

  Form = Struct.new(:required_fields, :standard_fields, :screening_questions, keyword_init: true)

  def self.payload(org, public_form: false, principal: nil)
    Form.new(
      required_fields: Array(org.setting("application_required_fields", DEFAULT_REQUIRED)),
      standard_fields: STANDARD_FIELDS,
      screening_questions: questions(public_form: public_form, principal: principal)
    )
  end

  def self.for_posting(org, posting)
    as_json(payload(org, public_form: true)).merge("posting_questions" => PostingQuestions.definitions(posting))
  end

  def self.as_json(form)
    {
      "required_fields" => form.required_fields,
      "standard_fields" => form.standard_fields,
      "screening_questions" => form.screening_questions.map { |field| question_json(field) }
    }
  end

  def self.questions(public_form: false, principal: nil)
    CustomField.where(entity: "application", show_on_apply: true, status: "active").order(:key).select do |field|
      if public_form
        Array(field.visibility_roles).empty?
      else
        field.visible_to?(principal)
      end
    end
  end

  # `screening_field_ids` nil leaves flags alone. An array is the full set of
  # application fields that should show on the public form (empty clears them).
  def self.update!(org, required_fields:, screening_field_ids: nil)
    fields = Array(required_fields).map(&:to_s).uniq
    unknown = fields - STANDARD_FIELDS
    raise ArgumentError, "unknown_fields:#{unknown.join(',')}" if unknown.any?

    missing = DEFAULT_REQUIRED - fields
    raise ArgumentError, "always_required:#{missing.join(',')}" if missing.any?

    Organization.transaction do
      org.merge_settings!("application_required_fields" => fields)
      sync_screening!(screening_field_ids) unless screening_field_ids.nil?
    end
    org.reload
  end

  def self.question_json(field)
    field.as_json(only: %i[id key label field_type required]).merge("options" => Array(field.options))
  end

  def self.sync_screening!(ids)
    ids = Array(ids).map(&:to_s).uniq
    fields = CustomField.where(entity: "application").to_a
    unknown = ids - fields.map(&:id)
    raise ArgumentError, "unknown_screening_fields:#{unknown.join(',')}" if unknown.any?

    archived = fields.select { |field| ids.include?(field.id) && !field.active? }
    raise ArgumentError, "archived_screening_field:#{archived.map(&:key).join(',')}" if archived.any?

    CustomField.transaction do
      fields.each do |field|
        show = ids.include?(field.id)
        next if field.show_on_apply == show

        CustomFieldDefinitions.update!(field, { "show_on_apply" => show })
      end
    end
  end
end
