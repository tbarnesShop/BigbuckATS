# frozen_string_literal: true

# Posting-local questions are deliberately separate from global custom fields.
module PostingQuestions
  TYPES = %w[text long_text number boolean email url select multi_select].freeze
  class Invalid < ArgumentError; end
  Field = Struct.new(:field_type, :option_keys)
  module_function

  def normalize(input)
    raise Invalid, "questions must be an array (maximum 50)" unless input.is_a?(Array) && input.length <= 50
    keys = []
    input.map do |raw|
      raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
      raise Invalid, "each question must be an object" unless raw.is_a?(Hash)
      q = raw.stringify_keys
      key, label, type = q.values_at("key", "label", "field_type")
      raise Invalid, "question key must be unique and use letters, numbers, or underscores" unless key.is_a?(String) && key.match?(/\A[a-z][a-z0-9_]{0,63}\z/) && !keys.include?(key)
      raise Invalid, "question label is required (maximum 500 characters)" unless label.is_a?(String) && label.strip.present? && label.length <= 500
      raise Invalid, "unsupported question type" unless TYPES.include?(type)
      raise Invalid, "required must be a boolean" unless q["required"].nil? || [ true, false ].include?(q["required"])
      options = q.fetch("options", [])
      unless options.is_a?(Array) && options.length <= 100 && options.all? { |o| o.is_a?(String) && o.present? && o.length <= 200 } && options.uniq == options
        raise Invalid, "options must be unique non-empty strings"
      end
      raise Invalid, "choice questions need options" if %w[select multi_select].include?(type) && options.empty?
      keys << key
      { "key" => key, "label" => label.strip, "field_type" => type, "required" => q["required"] == true, "options" => options }
    end
  end

  def definitions(posting)
    [ [ "template", posting.template_questions ], [ "posting", posting.questions ] ].flat_map do |source, rows|
      normalize(Array(rows)).map { |q| q.merge("key" => "#{source}.#{q.fetch('key')}", "source" => source) }
    end
  end

  def answers(questions, input)
    unknown = input.keys.grep(/\A(?:posting|template)\./) - questions.map { |q| q.fetch("key") }
    raise Invalid, "unknown posting questions" if unknown.any?
    questions.each_with_object({}) do |q, out|
      value = input[q.fetch("key")]
      blank = value.nil? || (value.respond_to?(:empty?) && value.empty?) || (value.is_a?(String) && value.strip.empty?)
      raise Invalid, "missing_fields:#{q.fetch('key')}" if blank && q["required"]
      next if blank
      valid_shape = case q["field_type"]
      when "multi_select" then value.is_a?(Array) && value.all? { |v| v.is_a?(String) }
      when "boolean" then value.is_a?(String) || [ true, false ].include?(value)
      when "number" then value.is_a?(String) || (value.is_a?(Numeric) && value.finite?)
      else value.is_a?(String)
      end
      raise Invalid, "#{q['key']}: invalid answer type" unless valid_shape
      raise Invalid, "answer is too long" if value.to_json.bytesize > 20_000
      attrs = CustomFieldTypes.coerce(Field.new(q["field_type"], q["options"]), value)
      out[q["key"]] = case q["field_type"]
      when "boolean" then attrs.dig(:value_json, "value")
      when "multi_select" then attrs.dig(:value_json, "values")
      when "number" then attrs[:value_number].to_f
      else attrs[:value_text]
      end
    rescue CustomFieldTypes::Invalid => error
      raise Invalid, "#{q['key']}: #{error.message}"
    end
  end
end
