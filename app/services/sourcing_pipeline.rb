# frozen_string_literal: true

# The default stage set for a sourcing pool: prospect -> reached out -> replied -> ready.
class SourcingPipeline
  STAGES = [
    { "key" => "prospect", "name" => "Prospect", "type" => "source" },
    { "key" => "reached-out", "name" => "Reached out", "type" => "outreach" },
    { "key" => "replied", "name" => "Replied", "type" => "outreach" },
    { "key" => "ready", "name" => "Ready", "type" => "ready" }
  ].freeze

  def self.default!
    template = PipelineTemplate.where(object_type: "project").order(:created_at).first ||
               PipelineTemplate.create!(key: "sourcing-default", name: "Sourcing", object_type: "project").tap { |t| t.publish!(stages: STAGES) }
    Pipeline.build_from_template!(template: template, scope: "project")
  end
end
