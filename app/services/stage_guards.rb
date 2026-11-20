# frozen_string_literal: true

# Entry/exit guards for subject stage moves. Fail-closed.
#
# Interview feedback is the exception: by default a stage's required interviews do not hold a move.
# Missing scorecards are reported (missing_scorecards) so the mover is warned, and the candidate can
# still go on. A stage holds for feedback only when its exit rules name `scorecards_submitted`.
class StageGuards
  Error = Class.new(StandardError)
  Failed = Class.new(Error)

  def self.check_exit!(subject:, from_stage_key:)
    new(subject).check_exit!(from_stage_key)
  end

  def self.check_entry!(subject:, to_stage_key:)
    new(subject).check_entry!(to_stage_key)
  end

  # Required interviews in the stage that still lack a submitted scorecard, as [{key, name}]. The board's
  # move preview shows these before a move is attempted, instead of a blanket warning.
  def self.missing_scorecards(subject:, stage_key:)
    new(subject).missing_scorecards(stage_key)
  end

  # True when the stage's own exit rules ask for scorecards, so missing ones refuse the move.
  def self.scorecards_required?(subject:, stage_key:)
    new(subject).scorecards_required?(stage_key)
  end

  def initialize(subject)
    @subject = subject
    @pipeline = subject.pipeline
  end

  def check_exit!(stage_key)
    stage = find_stage(stage_key)
    return if stage.nil?

    enforce_scorecards!(stage) if @subject.is_a?(Application)
    enforce_listed!(stage, "exit")
  end

  def missing_scorecards(stage_key)
    stage = find_stage(stage_key)
    interviews = Array(stage && stage["interviews"])
    return [] if interviews.empty?

    explicit = scorecard_rule(stage)
    keys = required_interview_keys(interviews, explicit ? explicit["scorecards_submitted"] : { "interviews" => "required" })
    keys.reject { |key| scorecard_submitted?(stage["key"], key) }.map do |key|
      { "key" => key, "name" => interviews.find { |i| i["key"] == key }&.dig("name") || key.tr("-_", "  ").capitalize }
    end
  end

  def scorecards_required?(stage_key)
    stage = find_stage(stage_key)
    stage.present? && scorecard_rule(stage).present?
  end

  def check_entry!(stage_key)
    stage = find_stage(stage_key)
    return if stage.nil?

    enforce_listed!(stage, "entry")
  end

  private

  def find_stage(key)
    Array(@pipeline.resolved_stages).find { |s| s["key"] == key }
  end

  def enforce_listed!(stage, side)
    require_list(stage, side).each do |guard|
      next if guard.is_a?(Hash) && guard.key?("scorecards_submitted") # handled separately

      if guard.is_a?(Hash) && guard.key?("fields_present")
        missing = Array(guard["fields_present"]).reject { |f| field_present?(f) }
        raise Failed, "fields_present:#{missing.join(",")}" if missing.any?
      elsif guard.is_a?(Hash) && guard.key?("when")
        ok = RuleEngine.evaluate(guard["when"], rule_context)
        raise Failed, guard["message"] || "when" unless ok
      end
    end
  end

  def enforce_scorecards!(stage)
    interviews = Array(stage["interviews"])
    return if interviews.empty?

    explicit = scorecard_rule(stage)
    return if explicit.nil? # feedback is expected, not enforced, unless the stage says so

    keys = required_interview_keys(interviews, explicit["scorecards_submitted"])
    return if keys.empty?

    missing = keys.reject { |key| scorecard_submitted?(stage["key"], key) }
    raise Failed, "scorecards_submitted:#{missing.join(",")}" if missing.any?
  end

  def scorecard_rule(stage)
    require_list(stage, "exit").find { |guard| guard.is_a?(Hash) && guard.key?("scorecards_submitted") }
  end

  def required_interview_keys(interviews, spec)
    mode = (spec || {})["interviews"]
    case mode
    when "required", nil
      interviews.select { |i| i["required"] != false }.map { |i| i["key"] }
    when "all"
      interviews.map { |i| i["key"] }
    when Array
      mode.map(&:to_s)
    else
      interviews.select { |i| i["required"] != false }.map { |i| i["key"] }
    end
  end

  def scorecard_submitted?(stage_key, interview_key)
    interview = Interview.find_by(application_id: @subject.id, stage_key: stage_key, interview_key: interview_key)
    return false unless interview

    Scorecard.exists?(interview_id: interview.id, status: "submitted")
  end

  def require_list(stage, side)
    side_cfg = stage[side] || stage["#{side}_requirements"]
    return [] if side_cfg.nil?

    if side_cfg.is_a?(Hash)
      Array(side_cfg["require"])
    else
      Array(side_cfg)
    end
  end

  def field_present?(field)
    path = field.to_s
    if path.start_with?("custom.")
      key = path.delete_prefix("custom.")
      cf = CustomField.find_by(entity: @subject.class.name.underscore, key: key)
      return false unless cf

      val = CustomFieldValue.find_by(custom_field_id: cf.id, entity_type: @subject.class.name, entity_id: @subject.id)
      val.present? && CustomFieldTypes.present?(val, cf.field_type)
    else
      @subject.respond_to?(path) && @subject.public_send(path).present?
    end
  end

  def rule_context
    {
      "subject" => { "status" => @subject.status, "current_stage_key" => @subject.current_stage_key },
      "person" => @subject.respond_to?(:person) ? { "id" => @subject.person_id } : {},
      "owner" => @subject.respond_to?(:job) ? { "id" => @subject.job_id } : {}
    }
  end
end
