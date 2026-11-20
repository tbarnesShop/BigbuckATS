# frozen_string_literal: true

require "test_helper"

class PanelBookingProposalTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 11, 1)
    @fake = CalendarClient::Fake.new
    CalendarClient.backend = @fake
    provisioned = OrganizationProvisioner.call(
      name: "PreviewCo", slug: "preview-#{SecureRandom.hex(3)}",
      owner_email: "owner-#{SecureRandom.hex(3)}@preview.test", owner_name: "Owner"
    )
    Current.organization_id = provisioned[:organization].id
    Current.actor_id = provisioned[:user].id
    @interviewer = User.create!(email: "int-#{SecureRandom.hex(3)}@preview.test", name: "Interviewer")
    template = PipelineTemplate.create!(key: "preview", name: "Preview", object_type: "job")
    template.publish!(stages: [
      { "key" => "screen", "name" => "Screen", "type" => "interview",
        "interviews" => [ { "key" => "phone", "name" => "Phone" } ] },
      { "key" => "offer", "name" => "Offer", "type" => "offer" }
    ])
    pipeline = Pipeline.build_from_template!(template: template)
    job = Job.create!(title: "Engineer", status: "active", pipeline: pipeline)
    @application = ApplicationCreator.call(job: job, person: Person.create!(display_name: "Test candidate"))
    @input = {
      interview_defs: [ { key: "phone", duration_minutes: 30, count: 1, candidate_user_ids: [ @interviewer.id ] } ],
      profiles: [ { user_id: @interviewer.id, paused: false } ],
      organizer_calendar: "recruiting@preview.test", user_emails: { @interviewer.id => @interviewer.email },
      search_start: Time.utc(2026, 11, 2, 9), search_end: Time.utc(2026, 11, 7, 17)
    }
  end

  teardown do
    CalendarClient.backend = nil
    Current.reset
    travel_back
  end

  def preview
    PanelBookingProposal.suggest(application: @application, **@input)
  end

  def confirm(option)
    PanelBookingProposal.confirm!(application: @application, token: option.fetch("token"))
  end

  test "preview has no side effects and confirmation books the selected second option exactly once" do
    options = nil
    assert_no_difference "Interview.count" do
      options = preview
    end
    assert_empty @fake.events
    assert_operator options.size, :>=, 2
    selected = options[1]
    result = confirm(selected)
    assert result.booked
    assert_equal Time.iso8601(selected["starts_at"]), result.interviews.first.starts_at
    assert_equal "screen", result.interviews.first.stage_key
    assert_equal [ @interviewer.email ], @fake.events.first[:attendees]
    assert_no_difference "Interview.count" do
      assert_equal "slot_unavailable", assert_raises(ArgumentError) { confirm(selected) }.message
    end
    assert_equal 1, @fake.events.size
  end

  test "a newly busy interviewer refuses the selected slot without booking an alternative" do
    selected = preview.first
    @fake.set_busy(@interviewer.id, [ [ Time.iso8601(selected["starts_at"]), Time.iso8601(selected["ends_at"]) ] ])
    assert_no_difference "Interview.count" do
      assert_equal "slot_unavailable", assert_raises(ArgumentError) { confirm(selected) }.message
    end
    assert_empty @fake.events
  end

  test "live calendar refusal after free busy does not silently choose another slot" do
    selected = preview.first
    @fake.define_singleton_method(:create_event_with_live_check!) { |**| raise CalendarClient::StaleSlot, "changed" }
    assert_no_difference "Interview.count" do
      assert_equal "slot_unavailable", assert_raises(ArgumentError) { confirm(selected) }.message
    end
    assert_empty @fake.events
  end

  test "changed stage or status invalidates the preview" do
    selected = preview.first
    @application.update!(current_stage_key: "offer")
    assert_equal "application_changed", assert_raises(ArgumentError) { confirm(selected) }.message
    @application.update!(current_stage_key: "screen", status: "rejected")
    assert_equal "application_changed", assert_raises(ArgumentError) { confirm(selected) }.message
    assert_empty @fake.events
  end

  test "expired tampered and wrong actor tokens cannot book" do
    selected = preview.first
    assert_equal "proposal_expired", assert_raises(ArgumentError) { confirm(selected.merge("token" => selected["token"] + "x")) }.message
    actor = Current.actor_id
    Current.actor_id = @interviewer.id
    assert_equal "proposal_expired", assert_raises(ArgumentError) { confirm(selected) }.message
    Current.actor_id = actor
    travel 11.minutes
    assert_equal "proposal_expired", assert_raises(ArgumentError) { confirm(selected) }.message
    assert_empty @fake.events
  end

  test "a token cannot be used for another application or after a pipeline edit" do
    selected = preview.first
    other = ApplicationCreator.call(job: @application.job, person: Person.create!(display_name: "Other candidate"))
    assert_equal "proposal_expired", assert_raises(ArgumentError) {
      PanelBookingProposal.confirm!(application: other, token: selected["token"])
    }.message
    @application.pipeline.increment!(:version)
    assert_equal "application_changed", assert_raises(ArgumentError) { confirm(selected) }.message
    assert_empty @fake.events
  end

  test "preview never proposes past times and rejects unbounded or invalid interviews" do
    travel_to Time.utc(2026, 11, 2, 10, 7)
    assert preview.all? { |option| Time.iso8601(option["starts_at"]) > Time.current }
    @input[:search_end] = @input[:search_start] + 15.days
    assert_equal "invalid_search_window", assert_raises(ArgumentError) { preview }.message
    @input[:search_end] = @input[:search_start] + 5.days
    @input[:interview_defs][0][:duration_minutes] = 0
    assert_equal "invalid_interview_plan", assert_raises(ArgumentError) { preview }.message
    assert_empty @fake.events
  end

  test "confirming a later pool option keeps the reviewed interviewer" do
    alternate = User.create!(email: "alternate-#{SecureRandom.hex(3)}@preview.test", name: "Alternate")
    @input[:interview_defs][0][:candidate_user_ids] << alternate.id
    @input[:profiles] << { user_id: alternate.id, paused: false }
    @input[:user_emails][alternate.id] = alternate.email
    options = preview
    selected = options.find { |option| option.dig("blocks", 0, "user_ids") == [ [ @interviewer.id, alternate.id ].max ] }
    assert selected
    assert_operator Time.iso8601(selected["starts_at"]), :>, @input[:search_start]
    result = confirm(selected)
    assert_equal selected.dig("blocks", 0, "user_ids"), result.interviews.first.interviewer_user_ids.sort
  end
end
