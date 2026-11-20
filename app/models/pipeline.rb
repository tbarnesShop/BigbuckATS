# frozen_string_literal: true

class Pipeline < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :pipeline_template, optional: true

  validates :scope, :resolved_stages, presence: true

  def self.build_from_template!(template:, overrides: [], scope: "job")
    stages = template.latest_stages
    result = PipelineResolver.call(template_stages: stages, overrides: overrides)
    create!(
      scope: scope,
      pipeline_template: template,
      template_version: template.published_version,
      overrides: overrides,
      resolved_stages: scope == "job" ? with_hired_stage(result.stages) : result.stages,
      needs_review: result.conflicts.any?,
      version: 1
    )
  end

  HIRED_STAGE = { "key" => "hired", "name" => "Hired", "type" => "hired", "origin" => "system", "interviews" => [] }.freeze

  # Every job pipeline ends in a Hired stage, so a hired candidate's stage reads "Hired", not "Offer".
  def self.with_hired_stage(stages)
    stages = Array(stages)
    return stages if stages.any? { |stage| stage["type"] == "hired" }
    key = stages.any? { |stage| stage["key"] == "hired" } ? "hired-final" : "hired"
    stages + [ HIRED_STAGE.merge("key" => key) ]
  end

  def reresolve!(template_stages: nil)
    stages = template_stages || pipeline_template.latest_stages
    result = PipelineResolver.call(template_stages: stages, overrides: overrides)
    assign_attributes(
      template_version: pipeline_template&.published_version || template_version,
      resolved_stages: scope == "job" ? self.class.with_hired_stage(result.stages) : result.stages,
      needs_review: result.conflicts.any?,
      version: version + 1
    )
    save!
    result
  end

  # Older pipelines predate the Hired stage; add it the first time someone is hired.
  def hired_stage_key!
    stage = Array(resolved_stages).find { |row| row["type"] == "hired" }
    return stage["key"] if stage
    update!(resolved_stages: self.class.with_hired_stage(resolved_stages), version: version + 1)
    Array(resolved_stages).find { |row| row["type"] == "hired" }["key"]
  end

  def stage(key)
    Array(resolved_stages).find { |row| row["key"] == key }
  end

  def stage_keys
    Array(resolved_stages).map { |s| s["key"] }
  end

  def first_stage_key
    stage_keys.first
  end
end
