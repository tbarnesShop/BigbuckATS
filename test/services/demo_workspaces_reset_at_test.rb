require "test_helper"

class DemoWorkspacesResetAtTest < ActiveSupport::TestCase
  setup do
    @prev_at = ENV["BIGBUCK_DEMO_RESET_AT"]
    @prev_tz = ENV["BIGBUCK_DEMO_RESET_TZ"]
    @prev_interval = ENV["BIGBUCK_DEMO_INTERVAL_HOURS"]
  end

  teardown do
    ENV["BIGBUCK_DEMO_RESET_AT"] = @prev_at
    ENV["BIGBUCK_DEMO_RESET_TZ"] = @prev_tz
    ENV["BIGBUCK_DEMO_INTERVAL_HOURS"] = @prev_interval
  end

  test "next_resets_at uses INTERVAL when RESET_AT is unset" do
    ENV.delete("BIGBUCK_DEMO_RESET_AT")
    travel_to Time.utc(2026, 11, 11, 12, 0, 0) do
      assert_equal Time.current + DemoWorkspaces::INTERVAL, DemoWorkspaces.next_resets_at
    end
  end

  test "next_resets_at aims at tonight when before the wall clock" do
    ENV["BIGBUCK_DEMO_RESET_AT"] = "03:00"
    ENV["BIGBUCK_DEMO_RESET_TZ"] = "America/New_York"
    # 2pm ET on Nov 10 = 19:00 UTC (EST).
    travel_to Time.utc(2026, 11, 10, 19, 0, 0) do
      assert_equal Time.utc(2026, 11, 11, 8, 0, 0), DemoWorkspaces.next_resets_at
    end
  end

  test "next_resets_at rolls to tomorrow after the wall clock so a 3am refresh does not re-fire immediately" do
    ENV["BIGBUCK_DEMO_RESET_AT"] = "03:00"
    ENV["BIGBUCK_DEMO_RESET_TZ"] = "America/New_York"
    # 3:05am ET = 08:05 UTC.
    travel_to Time.utc(2026, 11, 11, 8, 5, 0) do
      assert_equal Time.utc(2026, 11, 12, 8, 0, 0), DemoWorkspaces.next_resets_at
    end
  end

  test "manual daytime refresh still lands on the next 3am ET" do
    ENV["BIGBUCK_DEMO_RESET_AT"] = "03:00"
    ENV["BIGBUCK_DEMO_RESET_TZ"] = "America/New_York"
    travel_to Time.utc(2026, 11, 10, 19, 0, 0) do
      assert_equal Time.utc(2026, 11, 11, 8, 0, 0), DemoWorkspaces.next_resets_at
    end
  end
end
