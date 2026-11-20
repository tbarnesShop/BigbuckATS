# frozen_string_literal: true

# Compiles a list of config documents into a normalized manifest + hash.
class ConfigCompiler
  Document = Struct.new(:kind, :key, :spec, keyword_init: true)

  def self.compile(documents)
    new(documents).compile
  end

  def initialize(documents)
    @documents = Array(documents).map { |d| normalize(d) }
  end

  def compile
    items = @documents.sort_by { |d| [ d.kind, d.key ] }.map do |d|
      validate_rules!(d)
      { "kind" => d.kind, "key" => d.key, "spec" => deep_sort(d.spec) }
    end
    manifest = { "items" => items }
    hash = Digest::SHA256.hexdigest(CanonicalJson.dump(manifest))
    { manifest: manifest, hash: hash, items: items }
  end

  private

  def normalize(doc)
    h = doc.deep_stringify_keys
    Document.new(kind: h.fetch("kind"), key: h.fetch("key"), spec: h.fetch("spec"))
  end

  def validate_rules!(doc)
    walk = lambda do |node|
      case node
      when Hash
        if node.key?("when") || (node.key?("op") && RuleEngine::OPS.include?(node["op"]))
          rule = node["when"] || node
          RuleEngine.validate!(rule) if rule.is_a?(Hash)
        end
        node.each_value { |v| walk.call(v) }
      when Array
        node.each { |v| walk.call(v) }
      end
    end
    walk.call(doc.spec)
  end

  def deep_sort(value)
    case value
    when Hash
      value.keys.sort.index_with { |k| deep_sort(value[k]) }
    when Array
      value.map { |v| deep_sort(v) }
    else
      value
    end
  end
end

module CanonicalJson
  module_function

  def dump(obj)
    JSON.generate(canonical(obj))
  end
  def canonical(value)
    case value
    when Hash then value.keys.sort_by(&:to_s).to_h { |key| [ key.to_s, canonical(value[key]) ] }
    when Array then value.map { |item| canonical(item) }
    else value
    end
  end
end
