# frozen_string_literal: true

# The only way custom field definitions change. Every change bumps the field's
# version, writes a CustomFieldVersion row with the full definition, and goes
# through ChangeWriter (audit + outbox). Nothing here deletes stored values
# except an explicitly requested type change with on_unconvertible: "clear",
# which records which value ids were cleared.
class CustomFieldDefinitions
  class Error < StandardError
    attr_reader :code, :details

    def initialize(code, message = code, details: {})
      @code = code
      @details = details
      super(message)
    end
  end

  EDITABLE = %w[label description required filterable display_order visibility_roles options reference_type data_class show_on_apply].freeze
  CONVERT_BATCH = 500

  class << self
    def create!(entity:, key:, label:, field_type:, data_class: "internal", options: nil, description: nil,
                reference_type: nil, required: false, filterable: false, display_order: 0, visibility_roles: nil,
                show_on_apply: false)
      if show_on_apply && entity.to_s != "application"
        raise Error.new("show_on_apply_entity", "Only application fields can show on the careers form")
      end

      field = CustomField.new(
        entity: entity.to_s, key: key.to_s, label: label, field_type: CustomFieldTypes.canonical(field_type),
        data_class: data_class, options: normalize_options(options), description: description,
        reference_type: reference_type, required: required, filterable: filterable,
        display_order: display_order || 0, visibility_roles: visibility_roles, show_on_apply: show_on_apply,
        version: 1, status: "active"
      )
      CustomField.transaction do
        write!(field, "created")
      end
      field
    end

    def update!(field, attrs, expected_version: nil)
      attrs = attrs.to_h.stringify_keys
      unknown = attrs.keys - EDITABLE
      raise Error.new("not_editable", "Cannot change #{unknown.join(', ')} here; use a type change for field_type.") if unknown.any?
      if ActiveModel::Type::Boolean.new.cast(attrs["show_on_apply"]) && field.entity != "application"
        raise Error.new("show_on_apply_entity", "Only application fields can show on the careers form")
      end

      CustomField.transaction do
        field = lock!(field, expected_version)
        if attrs.key?("options")
          attrs["options"] = normalize_options(attrs["options"])
          removed = field.option_keys - option_keys(attrs["options"])
          in_use = removed.select { |key| option_in_use?(field, key) }
          if in_use.any?
            raise Error.new("option_in_use", "Options still used by stored values: #{in_use.join(', ')}. Change those values or run a type change first.",
                            details: { options: in_use })
          end
        end
        field.assign_attributes(attrs)
        write!(field, "updated")
      end
    end

    def archive!(field, expected_version: nil)
      set_status!(field, "archived", expected_version)
    end

    def restore!(field, expected_version: nil)
      set_status!(field, "active", expected_version)
    end

    # What a type change would do to existing values. Never exposes values.
    def preview_type_change(field, to_type:, options: nil, reference_type: nil)
      target = target_field(field, to_type, options, reference_type)
      total = convertible = 0
      unconvertible_ids = []
      field.custom_field_values.find_each(batch_size: CONVERT_BATCH) do |row|
        total += 1
        CustomFieldTypes.convert(row, field.field_type, target)
        convertible += 1
      rescue CustomFieldTypes::Invalid
        unconvertible_ids << row.id
      end
      {
        "from_type" => field.field_type, "to_type" => target.field_type, "total" => total,
        "convertible" => convertible, "unconvertible" => unconvertible_ids.size,
        "unconvertible_value_ids" => unconvertible_ids.first(50)
      }
    end

    # Converts every stored value to the new type, in batches, then bumps the
    # definition version. on_unconvertible: "refuse" (default) changes nothing
    # if any value cannot be converted; "clear" clears those values.
    def change_type!(field, to_type:, options: nil, reference_type: nil, on_unconvertible: "refuse", expected_version: nil)
      raise Error.new("invalid_strategy", "on_unconvertible must be refuse or clear") unless %w[refuse clear].include?(on_unconvertible)

      CustomField.transaction do
        field = lock!(field, expected_version)
        target = target_field(field, to_type, options, reference_type)
        preview = preview_type_change(field, to_type: to_type, options: options, reference_type: reference_type)
        if preview["unconvertible"].positive? && on_unconvertible == "refuse"
          raise Error.new("unconvertible_values",
                          "#{preview['unconvertible']} of #{preview['total']} values cannot become #{target.field_type}.",
                          details: preview)
        end

        new_version = field.version + 1
        cleared = []
        now = Time.current
        field.custom_field_values.find_each(batch_size: CONVERT_BATCH) do |row|
          attrs = begin
            CustomFieldTypes.convert(row, field.field_type, target)
          rescue CustomFieldTypes::Invalid
            cleared << row.id
            CustomFieldTypes.coerce(target, nil)
          end
          row.update_columns(attrs.merge(field_version: new_version, version: row.version + 1, updated_at: now))
        end

        field.assign_attributes(field_type: target.field_type, options: target.options, reference_type: target.reference_type)
        summary = preview.except("unconvertible_value_ids").merge("cleared_value_ids" => cleared, "strategy" => on_unconvertible)
        write!(field, "type_changed", summary: summary)
      end
    end

    private

    def write!(field, kind, summary: nil)
      field.version = field.new_record? ? 1 : field.version + 1 unless kind == "created"
      ChangeWriter.call(
        record: field,
        action: "custom_field.#{kind}",
        event_type: "custom_field.#{kind}",
        payload: { "key" => field.key, "entity" => field.entity, "field_type" => field.field_type,
                   "status" => field.status, "migration" => summary }.compact
      )
      CustomFieldVersion.create!(
        custom_field: field, version: field.version, change_kind: kind,
        definition: field.definition_snapshot, migration_summary: summary, actor_id: Current.audit_actor_id
      )
      field
    end

    def set_status!(field, status, expected_version)
      CustomField.transaction do
        field = lock!(field, expected_version)
        return field if field.status == status

        field.assign_attributes(status: status, archived_at: status == "archived" ? Time.current : nil)
        write!(field, status == "archived" ? "archived" : "restored")
      end
    end

    def lock!(field, expected_version)
      locked = CustomField.lock.find(field.id)
      if expected_version && locked.version != expected_version
        raise Error.new("stale_version", "Field is at version #{locked.version}, not #{expected_version}. Reload and retry.")
      end

      locked
    end

    def target_field(field, to_type, options, reference_type)
      target = CustomField.new(
        entity: field.entity, key: field.key, label: field.label, data_class: field.data_class,
        field_type: CustomFieldTypes.canonical(to_type),
        options: options.nil? ? field.options : normalize_options(options),
        reference_type: reference_type || field.reference_type, status: "active", version: field.version
      )
      unless CustomFieldTypes::ALL.include?(target.field_type)
        raise Error.new("invalid_type", "Unknown field type #{to_type}")
      end
      if CustomFieldTypes.option_type?(target.field_type) && target.option_keys.empty?
        raise Error.new("options_required", "#{target.field_type} needs options")
      end

      target
    end

    def normalize_options(options)
      return nil if options.nil?

      Array(options).map do |o|
        o.is_a?(Hash) ? { "key" => (o["key"] || o[:key]).to_s, "label" => (o["label"] || o[:label] || o["key"] || o[:key]).to_s } : { "key" => o.to_s, "label" => o.to_s }
      end
    end

    def option_keys(options)
      Array(options).map { |o| o["key"] }
    end

    def option_in_use?(field, key)
      if field.field_type == "multi_select"
        field.custom_field_values.where("JSON_CONTAINS(value_json->'$.values', JSON_QUOTE(?))", key).exists?
      else
        field.custom_field_values.where(value_text: key).exists?
      end
    end
  end
end
