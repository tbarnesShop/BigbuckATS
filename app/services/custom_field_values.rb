# frozen_string_literal: true

# Reads and writes custom field values against their current definition.
class CustomFieldValues
  ENTITY_MODELS = {
    "person" => "Person", "job" => "Job", "application" => "Application",
    "offer" => "Offer", "project" => "Project", "company" => "Company"
  }.freeze

  # Permission needed to write a value on each kind of record.
  WRITE_PERMISSIONS = {
    "person" => "person.update", "job" => "job.manage", "application" => "application.move_stage",
    "offer" => "offer.create", "project" => "project.manage", "company" => "company.manage"
  }.freeze

  class << self
    def entity_name(entity_type)
      name = entity_type.to_s.underscore
      raise CustomFieldDefinitions::Error.new("unknown_entity", "Unknown entity #{entity_type}") unless ENTITY_MODELS.key?(name)

      name
    end

    # Sets (or clears, with nil) one value. Returns the value row.
    def write!(entity_type:, entity_id:, key:, value:, expected_version: nil)
      entity = entity_name(entity_type)
      model = ENTITY_MODELS.fetch(entity).constantize
      raise ActiveRecord::RecordNotFound unless model.exists?(id: entity_id)

      field = CustomField.find_by(entity: entity, key: key.to_s)
      raise CustomFieldDefinitions::Error.new("unknown_field", "No #{entity} field named #{key}") unless field
      raise CustomFieldDefinitions::Error.new("field_archived", "#{key} is archived") unless field.active?

      begin
        attrs = CustomFieldTypes.coerce(field, value)
      rescue CustomFieldTypes::Invalid => e
        raise CustomFieldDefinitions::Error.new("invalid_value", "#{key}: #{e.message}")
      end
      if field.required && attrs.values.all?(&:nil?)
        raise CustomFieldDefinitions::Error.new("required", "#{key} is required")
      end

      CustomFieldValue.transaction do
        row = CustomFieldValue.lock.find_or_initialize_by(
          custom_field_id: field.id, entity_type: model.name, entity_id: entity_id
        )
        if expected_version && row.persisted? && row.version != expected_version
          raise CustomFieldDefinitions::Error.new("stale_version", "#{key} is at version #{row.version}, not #{expected_version}")
        end

        row.assign_attributes(attrs.merge(field_version: field.version, version: row.new_record? ? 1 : row.version + 1))
        ChangeWriter.call(
          record: row,
          action: "custom_field_value.set",
          event_type: "#{entity}.custom_field_changed",
          payload: { "entity_type" => model.name, "entity_id" => entity_id, "key" => field.key, "field_version" => field.version }
        )
        row.custom_field = field
        row
      end
    end

    # Active, visible fields and their values for many records at once:
    # { entity_id => [[field, row_or_nil], ...] } in display order.
    def for_entities(entity_type:, entity_ids:, keys: nil, principal: nil)
      entity = entity_name(entity_type)
      fields = CustomField.active.where(entity: entity).order(:display_order, :key).to_a
      fields = fields.select { |f| keys.map(&:to_s).include?(f.key) } if keys
      fields = fields.select { |f| f.visible_to?(principal) }
      return entity_ids.index_with { [] } if fields.empty?

      rows = CustomFieldValue.where(custom_field_id: fields.map(&:id), entity_type: ENTITY_MODELS.fetch(entity), entity_id: entity_ids)
                             .group_by(&:entity_id)
      entity_ids.index_with do |id|
        by_field = (rows[id] || []).index_by(&:custom_field_id)
        fields.filter_map do |field|
          row = by_field[field.id]
          next unless row && CustomFieldTypes.present?(row, field.field_type)

          row.custom_field = field
          row
        end
      end
    end
  end
end
