# frozen_string_literal: true

require "test_helper"

class RuleEngineStrictTest < ActiveSupport::TestCase
  CONTEXT = { "offer" => { "fields" => { "base-salary" => 200_000 } } }.freeze

  test "evaluate! returns the result for a valid rule" do
    rule = { "op" => "gt", "left" => "offer.fields.base-salary", "right" => 150_000 }
    assert RuleEngine.evaluate!(rule, CONTEXT)
    assert_not RuleEngine.evaluate!({ "op" => "lt", "left" => "offer.fields.base-salary", "right" => 1 }, CONTEXT)
  end

  test "a missing path is an ordinary no-match, not an error" do
    rule = { "op" => "eq", "left" => "offer.fields.missing", "right" => 1 }
    assert_equal false, RuleEngine.evaluate!(rule, CONTEXT)
  end

  test "evaluate! raises for an unknown op" do
    assert_raises(RuleEngine::Error) { RuleEngine.evaluate!({ "op" => "bogus", "left" => "a", "right" => "b" }, CONTEXT) }
  end

  test "evaluate! raises for a rule with a blank op" do
    assert_raises(RuleEngine::Error) { RuleEngine.evaluate!({ "op" => "", "left" => "a", "right" => "b" }, CONTEXT) }
  end

  test "evaluate! raises when a nested rule is malformed" do
    rule = { "op" => "and", "args" => [
      { "op" => "gt", "left" => "offer.fields.base-salary", "right" => 1 },
      { "op" => "bogus" }
    ] }
    assert_raises(RuleEngine::Error) { RuleEngine.evaluate!(rule, CONTEXT) }
  end

  test "evaluate! raises for a not rule without args" do
    assert_raises(RuleEngine::Error) { RuleEngine.evaluate!({ "op" => "not" }, CONTEXT) }
  end

  test "evaluate keeps its fail-closed false for malformed rules" do
    assert_equal false, RuleEngine.evaluate({ "op" => "bogus" }, CONTEXT)
    assert_equal false, RuleEngine.evaluate({ "op" => "", "left" => "a" }, CONTEXT)
  end
end
