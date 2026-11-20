# frozen_string_literal: true

require "test_helper"

# Proves the worked example in research/job-pipelines.md#worked-example
class PipelineResolverWorkedExampleTest < ActiveSupport::TestCase
  TEMPLATE_V1 = [
    { "key" => "review", "name" => "Application review", "type" => "review", "interviews" => [] },
    { "key" => "recruiter-screen", "name" => "Recruiter screen", "type" => "screen",
      "interviews" => [ { "key" => "recruiter-call", "name" => "Recruiter call" } ] },
    { "key" => "onsite", "name" => "Onsite", "type" => "interview",
      "interviews" => [
        { "key" => "coding", "name" => "Coding" },
        { "key" => "system-design", "name" => "System design" },
        { "key" => "values", "name" => "Values" }
      ] },
    { "key" => "offer", "name" => "Offer", "type" => "offer", "interviews" => [] }
  ].freeze

  JOB_EDITS = [
    { "op" => "add_stage", "key" => "take-home", "name" => "Take-home", "type" => "assessment", "after" => "recruiter-screen" },
    { "op" => "add_interview", "stage" => "recruiter-screen",
      "interview" => { "key" => "hiring-manager-chat", "name" => "Hiring manager chat" } },
    { "op" => "update_stage", "key" => "onsite", "name" => "Virtual onsite" },
    { "op" => "remove_interview", "stage" => "onsite", "interview" => "values" }
  ].freeze

  TEMPLATE_V2 = [
    { "key" => "review", "name" => "Application review", "type" => "review", "interviews" => [] },
    { "key" => "skills-test", "name" => "Skills assessment", "type" => "assessment",
      "interviews" => [ { "key" => "coding-test", "name" => "Coding test" } ] },
    { "key" => "recruiter-screen", "name" => "Recruiter call", "type" => "screen",
      "interviews" => [ { "key" => "recruiter-call", "name" => "Recruiter call" } ] },
    { "key" => "onsite", "name" => "Onsite", "type" => "interview",
      "interviews" => [
        { "key" => "coding", "name" => "Coding" },
        { "key" => "system-design", "name" => "System design" },
        { "key" => "bar-raiser", "name" => "Bar raiser" }
      ] },
    { "key" => "offer", "name" => "Offer", "type" => "offer", "interviews" => [] }
  ].freeze

  TEMPLATE_V3 = [
    { "key" => "review", "name" => "Application review", "type" => "review", "interviews" => [] },
    { "key" => "take-home", "name" => "Take-home", "type" => "assessment", "interviews" => [] },
    { "key" => "recruiter-screen", "name" => "Recruiter call", "type" => "screen",
      "interviews" => [ { "key" => "recruiter-call", "name" => "Recruiter call" } ] },
    { "key" => "final-round", "name" => "Final round", "type" => "interview",
      "interviews" => [ { "key" => "final", "name" => "Final" } ] },
    { "key" => "offer", "name" => "Offer", "type" => "offer", "interviews" => [] }
  ].freeze

  test "v1 template plus four job edits resolves as documented" do
    result = PipelineResolver.call(template_stages: TEMPLATE_V1, overrides: JOB_EDITS)
    assert_empty result.conflicts

    keys = result.stages.map { |s| s["key"] }
    assert_equal %w[review recruiter-screen take-home onsite offer], keys

    screen = result.stages.find { |s| s["key"] == "recruiter-screen" }
    assert_equal %w[recruiter-call hiring-manager-chat], screen["interviews"].map { |i| i["key"] }
    assert_equal "job", screen["interviews"].find { |i| i["key"] == "hiring-manager-chat" }["origin"]

    onsite = result.stages.find { |s| s["key"] == "onsite" }
    assert_equal "Virtual onsite", onsite["name"]
    assert_equal %w[coding system-design], onsite["interviews"].map { |i| i["key"] }

    take_home = result.stages.find { |s| s["key"] == "take-home" }
    assert_equal "job", take_home["origin"]
  end

  test "v2 template plus same edits re-applies cleanly" do
    result = PipelineResolver.call(template_stages: TEMPLATE_V2, overrides: JOB_EDITS)
    assert_empty result.conflicts
    assert_equal %w[review skills-test recruiter-screen take-home onsite offer], result.stages.map { |s| s["key"] }

    screen = result.stages.find { |s| s["key"] == "recruiter-screen" }
    assert_equal "Recruiter call", screen["name"]
    assert_includes screen["interviews"].map { |i| i["key"] }, "hiring-manager-chat"

    onsite = result.stages.find { |s| s["key"] == "onsite" }
    assert_equal %w[coding system-design bar-raiser], onsite["interviews"].map { |i| i["key"] }
  end

  test "v3 template produces conflicts for three edits" do
    result = PipelineResolver.call(template_stages: TEMPLATE_V3, overrides: JOB_EDITS)
    reasons = result.conflicts.map { |c| [ c["edit_index"], c["reason"] ] }
    assert_includes reasons, [ 0, "stage_exists" ] # take-home now in template
    assert_includes reasons, [ 2, "stage_missing" ] # onsite gone
    assert_includes reasons, [ 3, "stage_missing" ] # onsite gone
  end
end
