# frozen_string_literal: true

require "test_helper"

# A broken approval condition must surface as approval_gap, never fall through
# to the catch-all policy.
class ApprovalGapTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "GapPolicyCo", slug: "gp-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@gp.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id

    @catch_all = ApprovalPolicy.create!(
      key: "default-offers", name: "Default", applies_to: "offer",
      priority: 0, is_catch_all: true, conditions: nil
    )
  end

  teardown { Current.reset }

  test "a valid non-matching condition falls through to the catch-all" do
    ApprovalPolicy.create!(
      key: "high-salary", name: "High salary", applies_to: "offer", priority: 10, is_catch_all: false,
      conditions: { "op" => "gt", "left" => "offer.fields.base-salary", "right" => 500_000 }
    )
    matched = ApprovalPolicyMatcher.call(applies_to: "offer", context: { "offer" => { "fields" => { "base-salary" => 100_000 } } })
    assert_equal @catch_all.id, matched.id
  end

  test "a valid matching condition wins over the catch-all" do
    strict = ApprovalPolicy.create!(
      key: "high-salary", name: "High salary", applies_to: "offer", priority: 10, is_catch_all: false,
      conditions: { "op" => "gt", "left" => "offer.fields.base-salary", "right" => 150_000 }
    )
    matched = ApprovalPolicyMatcher.call(applies_to: "offer", context: { "offer" => { "fields" => { "base-salary" => 200_000 } } })
    assert_equal strict.id, matched.id
  end

  test "a malformed condition raises approval_gap instead of using the catch-all" do
    ApprovalPolicy.create!(
      key: "broken", name: "Broken", applies_to: "offer", priority: 10, is_catch_all: false,
      conditions: { "op" => "bogus", "left" => "offer.fields.base-salary", "right" => 1 }
    )
    error = assert_raises(ArgumentError) do
      ApprovalPolicyMatcher.call(applies_to: "offer", context: { "offer" => { "fields" => { "base-salary" => 200_000 } } })
    end
    assert_match(/approval_gap: condition_error/, error.message)
    assert_match(/broken/, error.message)
  end
end
