# frozen_string_literal: true

require "test_helper"

# schema.graphql is the committed GraphQL contract. Codegen for the web app, the
# MCP tools and the breaking-change check all read it, so it must match the code.
class SchemaDumpTest < ActiveSupport::TestCase
  test "schema.graphql matches BigbuckSchema" do
    path = Rails.root.join("schema.graphql")
    current = BigbuckSchema.to_definition
    committed = File.exist?(path) ? File.read(path) : ""
    return pass if committed == current

    # Print the schema so it can be committed as-is (bin/rails graphql:schema:dump).
    puts "\n----- BEGIN schema.graphql -----\n#{current}----- END schema.graphql -----"
    flunk "schema.graphql is out of date: run bin/rails graphql:schema:dump"
  end
end
