# frozen_string_literal: true

# Validates and normalizes a sequence's step list (step schema v2). Every step gets a stable id that
# survives reordering, so per-step stats keep meaning after edits.
#
#   email: { type, template_key, channel: "email", send_as_user_id? }
#   wait:  { type, days | hours | minutes }
#   task:  { type, title, task_type, assignee_user_id?, due_in_days?, pause_until_done? }
class SequenceSteps
  TYPES = %w[email wait task].freeze
  CHANNELS = %w[email].freeze
  MAX_STEPS = 20
  KEYS = {
    "email" => %w[template_key channel send_as_user_id],
    "wait" => %w[days hours minutes],
    "task" => %w[title task_type assignee_user_id due_in_days pause_until_done]
  }.freeze

  def self.normalize(steps)
    list = Array(steps).map { |s| s.respond_to?(:to_unsafe_h) ? s.to_unsafe_h : s.to_h }.map(&:stringify_keys)
    raise ArgumentError, "too_many_steps" if list.size > MAX_STEPS

    seen = Set.new
    list.each_with_index.map do |raw, index|
      type = raw["type"].to_s
      raise ArgumentError, "step_#{index + 1}_type_invalid" unless TYPES.include?(type)

      step = { "id" => raw["id"].presence || "s-#{SecureRandom.hex(4)}", "type" => type }
      raise ArgumentError, "step_#{index + 1}_id_duplicate" unless seen.add?(step["id"])

      KEYS.fetch(type).each { |k| step[k] = raw[k] unless raw[k].nil? || raw[k] == "" }
      send("check_#{type}!", step, index + 1)
      step
    end
  end

  def self.check_email!(step, position)
    step["channel"] ||= "email"
    raise ArgumentError, "step_#{position}_channel_invalid" unless CHANNELS.include?(step["channel"])
    raise ArgumentError, "step_#{position}_template_required" if step["template_key"].blank?
    raise ArgumentError, "step_#{position}_template_not_found" unless MessageTemplate.exists?(key: step["template_key"])
  end

  def self.check_wait!(step, position)
    unit = %w[minutes hours days].find { |k| step.key?(k) }
    unit ||= "days".tap { step["days"] = 1 }
    raise ArgumentError, "step_#{position}_wait_invalid" unless step[unit].to_i.positive?

    step[unit] = step[unit].to_i
  end

  def self.check_task!(step, position)
    raise ArgumentError, "step_#{position}_title_required" if step["title"].blank?
    step["task_type"] ||= "other"
    raise ArgumentError, "step_#{position}_task_type_invalid" unless SourcingTask::TYPES.include?(step["task_type"])
    step["pause_until_done"] = ActiveModel::Type::Boolean.new.cast(step.fetch("pause_until_done", true))
    step["due_in_days"] = step["due_in_days"].to_i if step.key?("due_in_days")
  end

  private_class_method :check_email!, :check_wait!, :check_task!
end
