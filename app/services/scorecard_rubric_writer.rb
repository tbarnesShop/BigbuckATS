# frozen_string_literal: true

# Creates and edits scorecard rubrics. Submit-time checks live on ScorecardSubmitter:
# when an interview definition names `rubric_key`, every required attribute
# must be rated.
#
# A rubric's key never changes (interview plans point at it). Attributes can be relabelled, made
# optional, added or dropped; ratings already given against a dropped attribute stay on their
# scorecards and keep showing there.
class ScorecardRubricWriter
  def self.create!(key:, name:, guidance: nil, attributes_spec: [])
    rubric = ScorecardRubric.new(
      key: key,
      name: name,
      guidance: guidance,
      attributes_spec: normalize(attributes_spec)
    )
    ChangeWriter.call(
      record: rubric,
      action: "scorecard_rubric.created",
      event_type: "scorecard_rubric.created",
      payload: { "key" => rubric.key, "name" => rubric.name }
    )
    rubric
  end

  def self.update!(rubric:, name: nil, guidance: :unchanged, attributes_spec: nil)
    rubric.name = name if name.present?
    rubric.guidance = guidance.presence unless guidance == :unchanged
    rubric.attributes_spec = normalize(attributes_spec) unless attributes_spec.nil?
    ChangeWriter.call(
      record: rubric,
      action: "scorecard_rubric.updated",
      event_type: "scorecard_rubric.updated",
      payload: { "key" => rubric.key, "name" => rubric.name }
    )
    rubric
  end

  def self.normalize(spec)
    Array(spec).map do |row|
      raw = if row.respond_to?(:to_unsafe_h)
              row.to_unsafe_h
      elsif row.respond_to?(:to_h)
              row.to_h
      else
              row
      end
      attrs = raw.stringify_keys.slice("key", "label", "guidance", "required")
      attrs["required"] = ActiveModel::Type::Boolean.new.cast(attrs["required"]) if attrs.key?("required")
      attrs
    end
  end
end
