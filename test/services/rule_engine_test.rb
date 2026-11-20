# frozen_string_literal: true

require "test_helper"

class RuleEngineTest < ActiveSupport::TestCase
  test "comparison and composition" do
    ctx = {
      "offer" => { "fields" => { "base-salary" => 200_000 } },
      "job" => { "dimensions" => { "level" => { "attributes" => { "salary-max" => 180_000 } } } },
      "person" => { "country" => "DE" }
    }
    assert RuleEngine.evaluate(
      { "op" => "gt", "left" => "offer.fields.base-salary", "right" => "job.dimensions.level.attributes.salary-max" },
      ctx
    )
    assert RuleEngine.evaluate(
      { "op" => "and", "args" => [
        { "op" => "eq", "left" => "person.country", "right" => "DE" },
        { "op" => "gte", "left" => "offer.fields.base-salary", "right" => 150_000 }
      ] },
      ctx
    )
  end

  test "dimension-style when map" do
    ctx = { "job" => { "dimensions" => { "department" => "engineering", "level" => "ic6" } } }
    assert RuleEngine.evaluate(
      { "job.dimensions.department" => "engineering", "job.dimensions.level" => %w[ic6 ic7] },
      ctx
    )
    refute RuleEngine.evaluate(
      { "job.dimensions.department" => "sales" },
      ctx
    )
  end

  test "fail closed on missing path" do
    refute RuleEngine.evaluate(
      { "op" => "eq", "left" => "offer.fields.missing", "right" => 1 },
      {}
    )
  end

  test "validate rejects unknown op" do
    assert_raises(RuleEngine::ValidationError) do
      RuleEngine.validate!({ "op" => "eval", "left" => "1", "right" => "1" })
    end
  end
end
