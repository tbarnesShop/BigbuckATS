# frozen_string_literal: true

# Closed structured-rule evaluator (no CEL, no eval).
class RuleEngine
  OPS = %w[eq neq gt gte lt lte in and or not].freeze
  Error = Class.new(StandardError)
  ValidationError = Class.new(Error)

  def self.evaluate(rule, context)
    new(context).evaluate(rule)
  end

  # Strict variant for decisions where "could not evaluate" must not look like
  # "did not match" (approvals). Raises RuleEngine::Error for a malformed rule;
  # a missing path or non-numeric value is still an ordinary false.
  def self.evaluate!(rule, context)
    new(context, strict: true).evaluate(rule)
  end

  def self.validate!(rule, allowed_paths: nil)
    new({}).validate!(rule, allowed_paths: allowed_paths)
  end

  def initialize(context, strict: false)
    @context = context.deep_stringify_keys
    @strict = strict
  end

  def evaluate(rule)
    return dimension_match?(rule) if dimension_style?(rule)

    rule = rule.deep_stringify_keys
    op = rule["op"]
    raise Error, "missing op" if op.blank?
    raise Error, "unknown op #{op}" unless OPS.include?(op)

    case op
    when "and" then Array(rule["args"]).all? { |a| evaluate(a) }
    when "or" then Array(rule["args"]).any? { |a| evaluate(a) }
    when "not" then !evaluate(rule.fetch("args").first)
    when "in"
      left = resolve(rule["left"])
      right = resolve(rule["right"])
      return false if left.nil?
      Array(right).map(&:to_s).include?(left.to_s)
    else
      compare(op, resolve(rule["left"]), resolve(rule["right"]))
    end
  rescue Error
    raise if @strict

    false # fail closed on evaluation errors
  rescue KeyError => e
    raise Error, "malformed rule: #{e.message}" if @strict

    raise
  end

  def validate!(rule, allowed_paths: nil)
    if dimension_style?(rule)
      rule.each_key do |path|
        check_path!(path, allowed_paths) if allowed_paths
      end
      return true
    end

    rule = rule.deep_stringify_keys
    op = rule["op"]
    raise ValidationError, "missing op" if op.blank?
    raise ValidationError, "unknown op #{op}" unless OPS.include?(op)

    case op
    when "and", "or"
      Array(rule["args"]).each { |a| validate!(a, allowed_paths: allowed_paths) }
    when "not"
      validate!(rule.fetch("args").first, allowed_paths: allowed_paths)
    else
      check_path!(rule["left"], allowed_paths) if rule["left"].is_a?(String) && allowed_paths
      check_path!(rule["right"], allowed_paths) if rule["right"].is_a?(String) && allowed_paths
    end
    true
  end

  private

  def dimension_style?(rule)
    rule.is_a?(Hash) && !rule.key?(:op) && !rule.key?("op")
  end

  def dimension_match?(rule)
    rule.deep_stringify_keys.all? do |path, expected|
      actual = resolve(path)
      values = Array(expected).map(&:to_s)
      values.include?(actual.to_s)
    end
  end

  def resolve(node)
    return node unless node.is_a?(String)
    return node unless node.include?(".")

    node.split(".").reduce(@context) do |acc, part|
      break nil if acc.nil?

      acc.is_a?(Hash) ? acc[part] : nil
    end
  end

  def compare(op, left, right)
    return false if left.nil? || right.nil?

    case op
    when "eq" then left.to_s == right.to_s
    when "neq" then left.to_s != right.to_s
    when "gt", "gte", "lt", "lte"
      l = Float(left)
      r = Float(right)
      case op
      when "gt" then l > r
      when "gte" then l >= r
      when "lt" then l < r
      when "lte" then l <= r
      end
    end
  rescue ArgumentError, TypeError
    false
  end

  def check_path!(path, allowed)
    return unless path.is_a?(String) && path.include?(".")
    return if allowed.any? { |p| path == p || path.start_with?("#{p}.") || p.end_with?(".*") && path.start_with?(p.delete_suffix(".*")) }

    raise ValidationError, "unknown path #{path}"
  end
end
