# frozen_string_literal: true

require "test_helper"

# MCP tools, the SDK and the CLI are generated from openapi/openapi.yaml, so a
# REST route that is not in it is invisible to agents and integrations, and a
# documented path with no route is a broken promise. Keep them identical.
class OpenapiContractTest < ActiveSupport::TestCase
  SPEC = Rails.root.join("openapi/openapi.yaml")
  METHODS = %w[get post put patch delete].freeze

  def normalize(path)
    path.gsub(/\{[^}]+\}/, "{}").gsub(/:[a-z_]+/, "{}")
  end

  def routed
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.delete_suffix("(.:format)")
      verb = route.verb.to_s.downcase
      next unless path.start_with?("/v1/") && METHODS.include?(verb)

      [ verb, normalize(path.delete_prefix("/v1")) ]
    end.uniq.then do |routes|
      # `resources ... :update` registers PUT as an alias of PATCH; the spec documents PATCH.
      routes.reject { |verb, path| verb == "put" && routes.include?([ "patch", path ]) }
    end
  end

  def documented
    spec = YAML.safe_load_file(SPEC)
    spec.fetch("paths").flat_map do |path, ops|
      ops.keys.select { |k| METHODS.include?(k) }.map { |verb| [ verb, normalize(path) ] }
    end.uniq
  end

  test "every /v1 route is documented in openapi.yaml" do
    missing = routed - documented
    assert_empty missing, "add these to openapi/openapi.yaml: #{missing.map { |v, p| "#{v.upcase} #{p}" }.join(', ')}"
  end

  test "every documented operation has a route" do
    extra = documented - routed
    assert_empty extra, "documented but not routed: #{extra.map { |v, p| "#{v.upcase} #{p}" }.join(', ')}"
  end

  test "operation ids are unique and non-public operations need a bearer token" do
    spec = YAML.safe_load_file(SPEC)
    ops = spec.fetch("paths").flat_map { |_p, h| h.select { |k, _| METHODS.include?(k) }.values }
    ids = ops.map { |op| op["operationId"] }
    assert_equal ids.size, ids.uniq.size
    assert_equal [ { "bearerAuth" => [] } ], spec["security"]
  end
end
