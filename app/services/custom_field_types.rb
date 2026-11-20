# frozen_string_literal: true

# The custom field type system: how each type is stored, read, coerced from
# input, and converted when a field's type changes.
#
#   text, long_text, email, url, phone, select, reference -> value_text
#   number, currency                                      -> value_number
#   date                                                  -> value_date
#   boolean                                               -> value_json {"value"=>bool}
#   multi_select                                          -> value_json {"values"=>[...]}
module CustomFieldTypes
  TEXT = %w[text long_text email url phone].freeze
  ALL = (TEXT + %w[string number currency date boolean select multi_select reference]).freeze
  REFERENCE_TYPES = %w[person job company user application].freeze
  TRUE_WORDS = %w[true yes y 1 on].freeze
  FALSE_WORDS = %w[false no n 0 off].freeze

  class Invalid < StandardError; end

  module_function

  def option_type?(type)
    %w[select multi_select].include?(type.to_s)
  end

  def canonical(type)
    type.to_s == "string" ? "text" : type.to_s
  end

  # Typed Ruby value from a stored row.
  def read(row, type)
    case canonical(type)
    when *TEXT, "select", "reference" then row.value_text
    when "number", "currency" then row.value_number&.then { |n| n.to_i == n ? n.to_i : n.to_f }
    when "date" then row.value_date
    when "boolean"
      raw = row.value_json
      raw.is_a?(Hash) ? raw["value"] : raw
    when "multi_select" then Array((row.value_json || {})["values"])
    end
  end

  def present?(row, type)
    value = read(row, type)
    !(value.nil? || (value.respond_to?(:empty?) && value.empty?))
  end

  # Column attributes for a value of this field. Raises Invalid when the input
  # cannot be this type (or is not one of the field's options).
  def coerce(field, input)
    type = canonical(field.field_type)
    blank = { value_text: nil, value_number: nil, value_date: nil, value_json: nil }
    return blank if input.nil? || (input.respond_to?(:empty?) && input.empty?)

    case type
    when "text", "long_text" then blank.merge(value_text: input.to_s)
    when "email"
      email = input.to_s.strip.downcase
      raise Invalid, "not an email address" unless email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)

      blank.merge(value_text: email)
    when "url"
      url = input.to_s.strip
      raise Invalid, "not a URL" unless url.match?(%r{\Ahttps?://\S+\z}i)

      blank.merge(value_text: url)
    when "phone"
      phone = PersonContactPoint.normalize_phone(input)
      raise Invalid, "not a phone number" if phone.gsub(/\D/, "").length < 5

      blank.merge(value_text: phone)
    when "number", "currency" then blank.merge(value_number: to_number(input))
    when "date" then blank.merge(value_date: to_date(input))
    when "boolean" then blank.merge(value_json: { "value" => to_boolean(input) })
    when "select"
      key = input.to_s
      raise Invalid, "#{key.inspect} is not an option (#{field.option_keys.join(', ')})" unless field.option_keys.include?(key)

      blank.merge(value_text: key)
    when "multi_select"
      keys = Array(input).flatten.map(&:to_s).uniq
      bad = keys - field.option_keys
      raise Invalid, "not options: #{bad.join(', ')}" if bad.any?

      blank.merge(value_json: { "values" => keys })
    when "reference" then blank.merge(value_text: input.to_s)
    else raise Invalid, "unknown type #{type}"
    end
  end

  def to_number(input)
    return input if input.is_a?(Numeric)

    text = input.to_s.strip.delete(",").delete_prefix("$")
    raise Invalid, "#{input.inspect} is not a number" unless text.match?(/\A-?\d+(\.\d+)?\z/)

    BigDecimal(text)
  end

  def to_date(input)
    return input.to_date if input.respond_to?(:to_date) && !input.is_a?(String)

    Date.iso8601(input.to_s.strip)
  rescue Date::Error, ArgumentError
    raise Invalid, "#{input.inspect} is not a date (YYYY-MM-DD)"
  end

  def to_boolean(input)
    return input if [ true, false ].include?(input)

    word = input.to_s.strip.downcase
    return true if TRUE_WORDS.include?(word)
    return false if FALSE_WORDS.include?(word)

    raise Invalid, "#{input.inspect} is not true or false"
  end

  # Converts a stored row from one type to another field definition. Returns
  # column attributes, or raises Invalid when the value cannot be carried over.
  def convert(row, from_type, to_field)
    value = read(row, from_type)
    return coerce(to_field, nil) if value.nil?

    value = case canonical(to_field.field_type)
    when "multi_select" then Array(value).map(&:to_s)
    when "select"
              list = Array(value)
              raise Invalid, "#{list.size} options cannot become one" if list.size > 1

              list.first.to_s
    when *TEXT, "reference"
              value.is_a?(Array) ? value.join(", ") : value.to_s
    when "boolean" then value.is_a?(Numeric) ? !value.zero? : value
    when "number", "currency" then value == true ? 1 : value == false ? 0 : value
    else value
    end
    coerce(to_field, value)
  end
end
