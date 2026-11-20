# frozen_string_literal: true

require "test_helper"

# M5a proving test: five-interview panel suggested and booked with live free/busy re-check.
class PanelBookingTest < ActiveSupport::TestCase
  setup do
    @fake = CalendarClient::Fake.new
    CalendarClient.backend = @fake

    @provisioned = OrganizationProvisioner.call(
      name: "SchedCo", slug: "sch-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@s.test", owner_name: "O"
    )
    Current.organization_id = @provisioned[:organization].id

    @users = Array.new(6) do |i|
      User.create!(email: "u#{i}-#{SecureRandom.hex(2)}@s.test", name: "User #{i}")
    end
    @hm, @p1, @p2, @p3, @named, @extra = @users

    @profiles = @users.map do |u|
      { user_id: u.id, paused: false, working_hours: { "mon" => [ [ "09:00", "17:00" ] ], "tue" => [ [ "09:00", "17:00" ] ],
                                                       "wed" => [ [ "09:00", "17:00" ] ], "thu" => [ [ "09:00", "17:00" ] ],
                                                       "fri" => [ [ "09:00", "17:00" ] ] } }
    end

    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [
      { "key" => "onsite", "name" => "Onsite", "type" => "interview",
        "interviews" => [
          { "key" => "hm", "name" => "HM" },
          { "key" => "pool-a", "name" => "Pool A" },
          { "key" => "pool-b", "name" => "Pool B" },
          { "key" => "pool-c", "name" => "Pool C" },
          { "key" => "named", "name" => "Named" },
          { "key" => "pair", "name" => "Pair" }
        ] }
    ])
    # Five interviews: HM, 3 pool, 1 named — plus pair needing two is 6 defs; spec says five-interview panel
    # with one needing two people. Use 5 defs: hm, 3 pool singles, 1 pair(count:2).
    pipeline = Pipeline.build_from_template!(template: template)
    job = Job.create!(title: "Platform", status: "active", pipeline: pipeline)
    person = Person.create!(display_name: "Cand", primary_email: "c@x.test")
    @application = ApplicationCreator.call(job: job, person: person)

    @defs = [
      { key: "hm", duration_minutes: 30, count: 1, candidate_user_ids: [ @hm.id ] },
      { key: "pool-a", duration_minutes: 45, count: 1, candidate_user_ids: [ @p1.id, @p2.id, @p3.id ] },
      { key: "pool-b", duration_minutes: 45, count: 1, candidate_user_ids: [ @p1.id, @p2.id, @p3.id ] },
      { key: "pool-c", duration_minutes: 45, count: 1, candidate_user_ids: [ @p1.id, @p2.id, @p3.id ] },
      { key: "pair", duration_minutes: 30, count: 2, candidate_user_ids: [ @named.id, @extra.id, @p1.id ] }
    ]

    @emails = @users.index_by(&:id).transform_values(&:email)
    # Next Monday 09:00 UTC window
    @start = Time.utc(2026, 11, 2, 9, 0, 0)
    @finish = @start + 5.days
  end

  teardown do
    CalendarClient.backend = nil
    Current.reset
  end

  test "suggests and books a five-interview panel" do
    result = PanelBooking.suggest_and_book!(
      application: @application,
      interview_defs: @defs,
      profiles: @profiles,
      organizer_calendar: "organizer@s.test",
      user_emails: @emails,
      search_start: @start,
      search_end: @finish
    )
    assert result.booked
    assert_equal 5, result.interviews.size
    assert_equal 5, Interview.where(application_id: @application.id, status: "scheduled").count
    assert_equal 5, @fake.events.size
  end

  test "stale option is refused and next-best is booked" do
    # Precompute options, then mark first option's interviewers busy before booking path
    free_busy = CalendarClient.free_busy(
      user_ids: @users.map(&:id), time_min: @start, time_max: @finish
    )
    options = AvailabilityEngine.suggest(
      interviews: @defs, profiles: @profiles, free_busy: free_busy,
      search_start: @start, search_end: @finish, limit: 3
    )
    assert options.size >= 2

    first = options.first
    first.blocks.each do |b|
      b.user_ids.each { |uid| @fake.set_busy(uid, [ [ b.starts_at, b.ends_at ] ]) }
    end

    result = PanelBooking.suggest_and_book!(
      application: @application,
      interview_defs: @defs,
      profiles: @profiles,
      organizer_calendar: "organizer@s.test",
      user_emails: @emails,
      search_start: @start,
      search_end: @finish
    )
    assert result.booked
    # Booked starts should not equal the stale first option start
    booked_start = result.interviews.map(&:starts_at).min
    assert_not_equal first.starts_at, booked_start
  end
end
