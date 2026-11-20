# frozen_string_literal: true

require "test_helper"

# End-to-end API coverage of the Big Buck dataset across roles.
class BigBuckDatasetE2eTest < ActionDispatch::IntegrationTest
  setup do
    @dataset = BigBuckDataset.call(slug: "big-buck-e2e-#{SecureRandom.hex(3)}", reset: false)
    @org = @dataset.organization
    @expectations = BigBuckDataset.expectations
    Current.reset
  end

  teardown { Current.reset }

  test "published demo jobs appear on public and internal careers" do
    Current.organization_id = @org.id
    expected_ids = @dataset.jobs.map(&:id).sort
    assert_equal %w[both], @dataset.jobs.map(&:careers_visibility).uniq
    assert_equal expected_ids, Job.on_careers("internal").pluck(:id).sort
    assert_equal expected_ids, Job.on_careers("public").pluck(:id).sort
    payload = BigBuckDataset.fixture_payload(@dataset)
    assert payload["jobs"].all? { |job| job["careers_visibility"] == "both" && job["careers_published"] }
  end

  test "internal opening backfill preserves records and explicit visibility choices" do
    Current.organization_id = @org.id
    platform, sales = @dataset.jobs.values_at(0, 1)
    platform.update!(careers_visibility: "public")
    sales.update!(careers_visibility: "hidden")
    before = [ Job.count, Posting.count, Application.count, Person.count ]
    BigBuckDataset.seed_internal_openings!(organization: @org)
    assert_equal "both", platform.reload.careers_visibility
    assert_equal "hidden", sales.reload.careers_visibility
    updated_at = platform.updated_at
    BigBuckDataset.seed_internal_openings!(organization: @org)
    assert_equal updated_at, platform.reload.updated_at
    assert_equal before, [ Job.count, Posting.count, Application.count, Person.count ]
    platform.update!(careers_visibility: "public")
    platform.postings.each { |posting| posting.update!(status: "draft") }
    BigBuckDataset.seed_internal_openings!(organization: @org)
    assert_equal "public", platform.reload.careers_visibility
    assert_empty Job.on_careers("internal")
  end

  test "dataset has one hundred candidates named Big Buck" do
    assert_equal "Big Buck", @org.name
    assert_equal 100, @dataset.people.size
    assert_equal BigBuckDataset.candidates.map { |c| c[:name] }.sort,
                 @dataset.people.map { |row| row[:person].display_name }.sort
  end

  test "candidates carry rich profile fields and related records" do
    Current.organization_id = @org.id
    person = @dataset.people.find { |row| row[:key] == "ava" }[:person]
    assert_predicate person.primary_phone, :present?
    assert_predicate person.country, :present?
    assert_predicate person.region, :present?
    assert person.contact_points.where(kind: "email").exists?
    assert person.contact_points.where(kind: "phone").exists?
    assert person.contact_points.where(kind: "url").exists?
    assert person.affiliations.exists?
    assert person.documents.exists?
    assert CustomFieldValue.where(entity_type: "Person", entity_id: person.id).exists?
    assert Consent.where(person_id: person.id).exists?
    assert NoticeReceipt.where(person_id: person.id).exists?

    stages = @dataset.applications.map(&:current_stage_key).uniq
    assert_includes stages, "applied"
    assert_includes stages, "onsite"
    assert_includes stages, "offer"
    assert @dataset.offers.any?
    assert Interview.exists?
    assert Scorecard.exists?
    assert SchedulingLink.exists?
    assert TimelineEvent.where(person_id: person.id).exists?
  end

  test "interview stage applications have a full loop with submitted scorecards" do
    Current.organization_id = @org.id
    eng_job = @dataset.jobs.find { |job| job.title == "Platform Engineer" }
    sales_job = @dataset.jobs.find { |job| job.title == "Account Executive" }
    interviewing = @dataset.applications.select { |app| app.current_stage_key.in?(%w[onsite offer]) }
    assert_operator interviewing.size, :>=, 8

    interviewing.each do |app|
      expected = app.job_id == sales_job.id ? %w[screen discovery case-study onsite] : %w[screen coding system-design onsite]
      interviews = Interview.where(application_id: app.id).order(:starts_at).to_a
      assert_equal expected, interviews.map(&:interview_key), "loop for application #{app.id}"
      assert interviews.all? { |interview| interview.status == "completed" }
      interviews.each do |interview|
        cards = interview.scorecards.to_a
        assert_predicate cards, :any?
        assert_equal interview.interviewer_user_ids.size, cards.size
        cards.each do |card|
          assert_equal "submitted", card.status
          assert_predicate card.notes, :present?
          assert_operator card.notes.length, :>, 40
          refute_match(/seed scorecard|placeholder|lorem ipsum|todo/i, card.notes)
          assert card.attribute_ratings.present?
        end
      end
      onsite = interviews.find { |interview| interview.interview_key == "onsite" }
      assert_operator onsite.scorecards.size, :>=, 2
      assert_operator TimelineEvent.where(person_id: app.person_id).count, :>=, 4
    end

    applied = @dataset.applications.select { |app| app.current_stage_key == "applied" && app.status == "active" }
    assert_predicate applied, :any?
    applied.each do |app|
      assert_equal 0, Interview.where(application_id: app.id).count
    end

    eng_stage = eng_job.pipeline.resolved_stages.find { |stage| stage["key"] == "onsite" }
    assert_equal %w[screen coding system-design onsite], eng_stage["interviews"].map { |row| row["key"] }
  end

  test "offers cover every status and the named anchors stay put" do
    Current.organization_id = @org.id
    statuses = @dataset.offers.map(&:status)
    assert_equal Offer::STATUSES.sort, statuses.uniq.sort

    ben = person_named("ben")
    farah = person_named("farah")
    priya = person_named("priya")
    assert_equal "draft", offer_for(ben).status
    assert_equal 185_000, offer_for(ben).current_version.fields["base_salary"]

    farah_offer = offer_for(farah)
    assert_equal "pending_approval", farah_offer.status
    approval = Approval.find_by!(entity_type: "Offer", entity_id: farah_offer.id, status: "pending")
    assert_equal @dataset.users.fetch("hiring_manager").id, approval.approver_user_id

    priya_offer = offer_for(priya)
    assert_equal "sent", priya_offer.status
    assert SignatureRequest.exists?(offer_version_id: priya_offer.current_version_id, status: "sent")

    assert @dataset.offers.any? { |offer| offer.status == "approved" }
    assert @dataset.offers.any? { |offer| offer.status == "changes_requested" }
    assert TimelineEvent.exists?(event_type: "offer.pending_approval")
    assert TimelineEvent.exists?(event_type: "offer.sent")
  end

  test "roles cover admin recruiter hiring_manager and non_user" do
    Current.organization_id = @org.id
    assert @dataset.roles.key?("admin")
    assert @dataset.roles.key?("recruiter")
    assert @dataset.roles.key?("hiring_manager")
    assert_includes @dataset.roles.fetch("admin").permissions, "person.read_restricted"
    assert_includes @dataset.roles.fetch("recruiter").permissions, "person.read"
    refute_includes @dataset.roles.fetch("recruiter").permissions, "person.read_restricted"
    assert_includes @dataset.roles.fetch("hiring_manager").permissions, "person.read"
    refute_includes @dataset.roles.fetch("hiring_manager").permissions, "person.create"
    assert_nil Membership.find_by(user: @dataset.users.fetch("non_user"), organization_id: @org.id)
    refute @dataset.memberships.fetch("hiring_manager").org_wide?
    refute @dataset.memberships.fetch("sales_hm").org_wide?
  end

  test "users have interviewer profiles, calendars, pools, and hiring teams" do
    Current.organization_id = @org.id
    assert_equal 7, @dataset.interviewer_profiles.size
    assert @dataset.interviewer_profiles.any? { |p| p.time_zone == "Europe/Berlin" }
    assert @dataset.interviewer_profiles.any? { |p| p.daily_limit == 6 }

    assert_equal 8, @dataset.calendar_connections.size
    assert @dataset.calendar_connections.any? { |c| c.kind == "domain" }
    assert_equal 7, @dataset.calendar_connections.count { |c| c.kind == "user" }

    assert_equal 2, @dataset.interviewer_pools.size
    keys = @dataset.interviewer_pools.map(&:key).sort
    assert_equal %w[eng-panel sales-panel], keys
    eng_pool = @dataset.interviewer_pools.find { |p| p.key == "eng-panel" }
    assert_operator eng_pool.members.size, :>=, 3

    assert_equal 2, @dataset.hiring_teams.size
    eng_team = @dataset.hiring_teams.find { |t| t.job_id == @dataset.jobs.find { |j| j.title == "Platform Engineer" }.id }
    roles = eng_team.members.map(&:team_role).sort
    assert_includes roles, "hiring-manager"
    assert_includes roles, "recruiter"
    assert_includes roles, "interviewer"

    assert_equal 3, @dataset.rooms.size
    assert_equal 2, @dataset.holidays.size
    assert InterviewerBlock.exists?(user_id: @dataset.users.fetch("hiring_manager").id)
    assert ApprovalPolicyStep.exists?
  end

  test "admin lists all people including restricted" do
    get "/v1/people", headers: headers_for("admin")
    assert_response :success
    names = response.parsed_body.fetch("data").map { |p| p["display_name"] }
    assert_equal @expectations.fetch("admin_count"), names.size
    assert_includes names, "Diego Santos"
    assert_includes names, "Uma Sharma"
  end

  test "recruiter lists only public people" do
    get "/v1/people", headers: headers_for("recruiter")
    assert_response :success
    names = response.parsed_body.fetch("data").map { |p| p["display_name"] }
    assert_equal @expectations.fetch("recruiter_count"), names.size
    refute_includes names, "Diego Santos"
    refute_includes names, "Ian Brooks"
    refute_includes names, "Nina Patel"
    refute_includes names, "Uma Sharma"
    assert_includes names, "Ava Chen"
  end

  test "hiring manager lists only public engineering-scoped people" do
    get "/v1/people", headers: headers_for("hiring_manager")
    assert_response :success
    names = response.parsed_body.fetch("data").map { |p| p["display_name"] }
    expected = @expectations.fetch("hiring_manager_names")
    assert_equal expected.sort, names.sort
    assert_includes names, "Ava Chen"
    refute_includes names, "Kai Nakamura"
    refute_includes names, "Diego Santos"
    refute_includes names, "Rosa Alvarez"
  end

  test "non-user with actor header sees an empty people list" do
    get "/v1/people", headers: {
      "X-Organization-Id" => @org.id,
      "X-Actor-Id" => @dataset.users.fetch("non_user").id
    }
    assert_response :success
    assert_equal [], response.parsed_body.fetch("data")
  end

  test "sourcing pools seed with members on a project pipeline" do
    Current.organization_id = @org.id
    projects = @dataset.projects
    assert_equal 2, projects.size
    assert_equal [ "AE talent pool", "Platform warm bench" ].sort, projects.map(&:name).sort
    platform = projects.find { |p| p.name == "Platform warm bench" }
    assert_equal 4, platform.pipeline.resolved_stages.size
    members = @dataset.project_members.select { |m| m.project_id == platform.id }
    assert members.size >= 3
    assert_includes members.map(&:current_stage_key), "ready"
    get "/v1/projects", headers: headers_for("recruiter")
    assert_response :success
    assert_equal 2, response.parsed_body.fetch("data").size
  end

  test "jobs are listed for recruiters" do
    get "/v1/jobs", headers: headers_for("recruiter")
    assert_response :success
    titles = response.parsed_body.fetch("data").map { |j| j["title"] }
    assert_includes titles, "Platform Engineer"
    assert_includes titles, "Account Executive"
  end

  private

  def person_named(key)
    @dataset.people.find { |row| row[:key] == key }.fetch(:person)
  end

  def offer_for(person)
    app = @dataset.applications.find { |row| row.person_id == person.id }
    @dataset.offers.find { |offer| offer.application_id == app.id }
  end

  def headers_for(role)
    {
      "X-Organization-Id" => @org.id,
      "X-Actor-Id" => @dataset.users.fetch(role).id
    }
  end
end
