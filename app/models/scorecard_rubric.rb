# frozen_string_literal: true

# A named set of attributes an interviewer rates on a scorecard, for example
# problem solving and communication. An interview definition in a pipeline
# names one with `rubric_key`; the scorecard cannot be submitted until every
# required attribute has a rating.
class ScorecardRubric < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :key, :name, presence: true
  validates :key, uniqueness: { scope: :organization_id }
  validates :attributes_spec, presence: true
  validate :attributes_spec_shape

  # Attribute keys that must be rated. An attribute is required unless it says
  # `"required": false`.
  def required_keys
    entries.reject { |entry| entry["required"] == false }.map { |entry| entry["key"] }
  end

  def attribute_keys
    entries.map { |entry| entry["key"] }
  end

  private

  def entries
    Array(attributes_spec).select { |entry| entry.is_a?(Hash) }.map(&:stringify_keys)
  end

  def attributes_spec_shape
    return if attributes_spec.blank?

    unless attributes_spec.is_a?(Array) && attributes_spec.all? { |entry| entry.is_a?(Hash) }
      errors.add(:attributes_spec, "must be a list of attributes")
      return
    end

    keys = entries.map { |entry| entry["key"].to_s }
    errors.add(:attributes_spec, "every attribute needs a key") if keys.any?(&:blank?)
    errors.add(:attributes_spec, "attribute keys must be unique") if keys.uniq.size != keys.size
  end
end
