# frozen_string_literal: true

require "test_helper"

class AvailabilityEngineTest < ActiveSupport::TestCase
  test "skips holiday dates when suggesting" do
    users = %w[u1 u2]
    profiles = users.map { |id| { user_id: id, paused: false } }
    defs = [
      { key: "hm", duration_minutes: 30, count: 1, candidate_user_ids: users }
    ]
    start = Time.utc(2026, 11, 2, 9, 0, 0) # Monday
    finish = start + 3.days

    with_holiday = AvailabilityEngine.suggest(
      interviews: defs, profiles: profiles, free_busy: {},
      search_start: start, search_end: finish,
      holiday_dates: [ Date.new(2026, 11, 2) ], limit: 3
    )
    assert with_holiday.any?
    assert with_holiday.all? { |o| o.starts_at.to_date != Date.new(2026, 11, 2) }
  end

  test "uses local working hours through daylight saving changes and rounds search up" do
    [ Time.utc(2026, 10, 30, 12), Time.utc(2026, 11, 2, 12) ].each do |start|
      options = AvailabilityEngine.suggest(
        interviews: [ { key: "screen", duration_minutes: 30, count: 1, candidate_user_ids: [ "riley" ] } ],
        profiles: [ { user_id: "riley", time_zone: "America/New_York", working_hours: { "mon" => [ [ "09:00", "17:00" ] ], "fri" => [ [ "09:00", "17:00" ] ] } } ],
        free_busy: {}, search_start: start, search_end: start + 1.day
      )
      assert options.any?
      assert_equal 9, options.first.starts_at.in_time_zone("America/New_York").hour
      assert options.all? { |option| option.ends_at.in_time_zone("America/New_York").hour < 17 }
    end
    start = Time.utc(2026, 11, 2, 9, 7)
    options = AvailabilityEngine.suggest(
      interviews: [ { key: "screen", duration_minutes: 30, candidate_user_ids: [ "a" ] } ],
      profiles: [ { user_id: "a" } ], free_busy: {}, search_start: start, search_end: start + 1.hour
    )
    assert_equal Time.utc(2026, 11, 2, 9, 15), options.first.starts_at
  end

  test "rooms are listed and keyed per organization" do
    provisioned = OrganizationProvisioner.call(
      name: "RoomCo", slug: "r-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@r.test", owner_name: "O"
    )
    Current.organization_id = provisioned[:organization].id
    room = Room.create!(key: "board-a", name: "Board A", resource_email: "board-a@resource.calendar.google.com", capacity: 6)
    assert_equal "board-a", room.key
    Holiday.create!(name: "Company Day", observed_on: Date.new(2026, 12, 24))
    assert_equal 1, Holiday.count
  ensure
    Current.reset
  end
end
