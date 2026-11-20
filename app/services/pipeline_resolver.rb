# frozen_string_literal: true

# Pure resolver: template stages + ordered overrides → resolved stages.
# Used by the worked example and by Pipeline#reresolve!
class PipelineResolver
  Result = Struct.new(:stages, :conflicts, keyword_init: true)

  def self.call(template_stages:, overrides:)
    new(template_stages: template_stages, overrides: overrides).call
  end

  def initialize(template_stages:, overrides:)
    @stages = deep_dup_stages(template_stages)
    @overrides = Array(overrides)
    @conflicts = []
  end

  def call
    @overrides.each_with_index do |edit, index|
      apply_edit(edit.stringify_keys, index)
    end
    Result.new(stages: @stages, conflicts: @conflicts)
  end

  private

  def deep_dup_stages(stages)
    Array(stages).map { |s| s.deep_stringify_keys.deep_dup }
  end

  def apply_edit(edit, index)
    case edit["op"]
    when "add_stage"
      add_stage(edit, index)
    when "update_stage"
      update_stage(edit, index)
    when "remove_stage"
      remove_stage(edit, index)
    when "add_interview"
      add_interview(edit, index)
    when "remove_interview"
      remove_interview(edit, index)
    when "move_stage"
      move_stage(edit, index)
    else
      @conflicts << { "edit_index" => index, "reason" => "unknown_op", "op" => edit["op"] }
    end
  end

  def add_stage(edit, index)
    key = edit.fetch("key")
    if @stages.any? { |s| s["key"] == key }
      @conflicts << { "edit_index" => index, "reason" => "stage_exists", "key" => key }
      return
    end

    stage = {
      "key" => key,
      "name" => edit.fetch("name"),
      "type" => edit.fetch("type"),
      "origin" => "job",
      "interviews" => Array(edit["interviews"]).map { |i| i.merge("origin" => "job") }
    }
    after = edit["after"]
    if after
      i = @stages.index { |s| s["key"] == after }
      if i
        @stages.insert(i + 1, stage)
      else
        @conflicts << { "edit_index" => index, "reason" => "after_missing", "after" => after }
        @stages << stage
      end
    else
      @stages << stage
    end
  end

  def update_stage(edit, index)
    stage = @stages.find { |s| s["key"] == edit["key"] }
    unless stage
      @conflicts << { "edit_index" => index, "reason" => "stage_missing", "key" => edit["key"] }
      return
    end
    stage["name"] = edit["name"] if edit.key?("name")
    stage["type"] = edit["type"] if edit.key?("type")
  end

  def remove_stage(edit, index)
    unless @stages.any? { |s| s["key"] == edit["key"] }
      @conflicts << { "edit_index" => index, "reason" => "stage_missing", "key" => edit["key"] }
      return
    end
    @stages.reject! { |s| s["key"] == edit["key"] }
  end

  # Reorder: place the stage right after `after` (nil puts it first).
  def move_stage(edit, index)
    i = @stages.index { |s| s["key"] == edit["key"] }
    unless i
      @conflicts << { "edit_index" => index, "reason" => "stage_missing", "key" => edit["key"] }
      return
    end
    stage = @stages.delete_at(i)
    after = edit["after"]
    if after.nil?
      @stages.unshift(stage)
    elsif (j = @stages.index { |s| s["key"] == after })
      @stages.insert(j + 1, stage)
    else
      @stages.insert(i, stage)
      @conflicts << { "edit_index" => index, "reason" => "after_missing", "after" => after }
    end
  end

  def add_interview(edit, index)
    stage = @stages.find { |s| s["key"] == edit["stage"] }
    unless stage
      @conflicts << { "edit_index" => index, "reason" => "stage_missing", "key" => edit["stage"] }
      return
    end
    stage["interviews"] ||= []
    interview = edit.fetch("interview").stringify_keys.merge("origin" => "job")
    if stage["interviews"].any? { |i| i["key"] == interview["key"] }
      @conflicts << { "edit_index" => index, "reason" => "interview_exists", "key" => interview["key"] }
      return
    end
    stage["interviews"] << interview
  end

  def remove_interview(edit, index)
    stage = @stages.find { |s| s["key"] == edit["stage"] }
    unless stage
      @conflicts << { "edit_index" => index, "reason" => "stage_missing", "key" => edit["stage"] }
      return
    end
    # Removing an interview already absent (e.g. template dropped it) is a clean no-op.
    stage["interviews"] = Array(stage["interviews"]).reject { |i| i["key"] == edit["interview"] }
  end
end
