# frozen_string_literal: true

# Turns applied config-as-code objects into real configuration. Before M9e,
# apply only stored specs in config_objects; nothing changed behaviour. Each
# executor validates a spec at plan time and applies it inside the apply
# transaction, so a failing executor refuses the whole plan.
#
# Kinds without an executor (e.g. ReasonSet) are stored as before.
module ConfigExecutors
  class Invalid < StandardError
    attr_reader :identity

    def initialize(identity, message)
      @identity = identity
      super("#{identity}: #{message}")
    end
  end

  module CustomField
    module_function

    # key: "<entity>.<field key>" (or spec entity + key)
    def locate(key, spec)
      entity, field_key = key.to_s.include?(".") ? key.to_s.split(".", 2) : [ spec["entity"], spec["key"] || key ]
      raise Invalid.new("CustomField/#{key}", "needs an entity: use key 'person.<field>' or spec.entity") if entity.blank?

      [ entity, field_key ]
    end

    def validate!(key, spec)
      locate(key, spec)
      type = spec["type"] || spec["field_type"]
      raise Invalid.new("CustomField/#{key}", "spec.type is required") if type.blank?
      raise Invalid.new("CustomField/#{key}", "unknown type #{type}") unless CustomFieldTypes::ALL.include?(type.to_s)
    end

    # Plan-time impact of an update: a type change and how many values convert.
    def preview(key, spec)
      entity, field_key = locate(key, spec)
      field = ::CustomField.find_by(entity: entity, key: field_key)
      type = CustomFieldTypes.canonical(spec["type"] || spec["field_type"])
      return nil unless field && field.field_type != type

      CustomFieldDefinitions.preview_type_change(field, to_type: type, options: spec["options"])
    rescue CustomFieldDefinitions::Error
      nil
    end

    def apply!(op, key, spec)
      entity, field_key = locate(key, spec || {})
      field = ::CustomField.find_by(entity: entity, key: field_key)

      if op == "archive"
        CustomFieldDefinitions.archive!(field) if field&.active?
        return
      end

      type = CustomFieldTypes.canonical(spec["type"] || spec["field_type"])
      attrs = {
        "label" => spec["label"] || field&.label || field_key.humanize,
        "description" => spec["description"], "data_class" => spec["data_class"] || field&.data_class || "internal",
        "options" => spec["options"], "reference_type" => spec["reference_type"],
        "required" => spec.fetch("required", false), "filterable" => spec.fetch("filterable", false),
        "display_order" => spec.fetch("display_order", 0)
      }

      if field.nil?
        CustomFieldDefinitions.create!(entity: entity, key: field_key, field_type: type, **attrs.symbolize_keys)
        return
      end

      CustomFieldDefinitions.restore!(field) unless field.active?
      if field.reload.field_type != type
        CustomFieldDefinitions.change_type!(field, to_type: type, options: spec["options"], reference_type: spec["reference_type"],
                                                   on_unconvertible: spec["on_unconvertible"] || "refuse")
      end
      field.reload
      changed = attrs.reject { |name, value| name == "options" ? value.nil? || field.option_keys == Array(value).map { |o| o.is_a?(Hash) ? o["key"].to_s : o.to_s } : field.public_send(name) == value }
      CustomFieldDefinitions.update!(field, changed) if changed.any?
    rescue CustomFieldDefinitions::Error, ActiveRecord::RecordInvalid => e
      raise Invalid.new("CustomField/#{key}", e.message)
    end
  end

  module PipelineTemplate
    module_function

    def validate!(key, spec)
      stages = Array(spec["stages"])
      raise Invalid.new("PipelineTemplate/#{key}", "spec.stages must list at least one stage") if stages.empty?

      stages.each do |stage|
        missing = %w[key name type].reject { |k| stage[k].present? }
        raise Invalid.new("PipelineTemplate/#{key}", "stage needs #{missing.join(', ')}") if missing.any?
      end
    end

    def preview(_key, _spec) = nil

    # Publishes a new template version when the stages changed. Jobs keep the
    # version they were built from until someone re-resolves them.
    def apply!(op, key, spec)
      return if op == "archive"

      template = ::PipelineTemplate.find_or_initialize_by(key: key)
      template.name = spec["name"].presence || template.name || key.humanize
      template.object_type ||= "job"
      template.save!
      current = template.published_version.positive? ? template.latest_stages : nil
      desired = template.send(:normalize_template_stages, spec["stages"])
      template.publish!(stages: spec["stages"]) unless current == desired
    rescue ActiveRecord::RecordInvalid, KeyError => e
      raise Invalid.new("PipelineTemplate/#{key}", e.message)
    end
  end

  REGISTRY = { "CustomField" => CustomField, "PipelineTemplate" => PipelineTemplate }.freeze

  module_function

  def for(kind)
    REGISTRY[kind.to_s]
  end

  def validate!(kind, key, spec)
    self.for(kind)&.validate!(key, spec.to_h.deep_stringify_keys)
  end

  def preview(kind, key, spec)
    self.for(kind)&.preview(key, spec.to_h.deep_stringify_keys)
  end

  def apply!(op, kind, key, spec)
    self.for(kind)&.apply!(op, key, spec.to_h.deep_stringify_keys)
  end
end
