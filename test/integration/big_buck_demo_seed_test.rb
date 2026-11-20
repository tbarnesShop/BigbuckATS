# frozen_string_literal: true

require "test_helper"

# The demo enrichment layered on BigBuckDataset: richness, internal coherence, idempotency, and reset.
class BigBuckDemoSeedTest < ActiveSupport::TestCase
  COUNTED = [ Job, Person, Application, Interview, Scorecard, Offer, Document, MessageTemplate, Sequence, SequenceEnrollment,
              Project, ProjectMember, Referral, Requisition, Posting, Communication, SourcingTask ].freeze

  setup do
    @slug = "big-buck-demo-#{SecureRandom.hex(3)}"
    # Keep the suite fast: production/lab demos still default to 800 via BIGBUCK_DEMO_PEOPLE_TARGET.
    @previous_people_target = ENV["BIGBUCK_DEMO_PEOPLE_TARGET"]
    ENV["BIGBUCK_DEMO_PEOPLE_TARGET"] = "420"
    @result = BigBuckDemoSeed.call(slug: @slug, reset: false)
    @org = @result.organization
    Current.organization_id = @org.id
  end

  teardown do
    if @previous_people_target
      ENV["BIGBUCK_DEMO_PEOPLE_TARGET"] = @previous_people_target
    else
      ENV.delete("BIGBUCK_DEMO_PEOPLE_TARGET")
    end
    Current.reset
  end

  def counts
    Current.organization_id = @org.id
    COUNTED.to_h { |model| [ model.name, model.count ] }
  end

  test "every stage of the main pipelines is populated and jobs cover every status" do
    %w[Senior\ Product\ Designer Product\ Manager,\ Growth Customer\ Success\ Manager Staff\ Site\ Reliability\ Engineer
       Sales\ Development\ Representative VP\ of\ Marketing].each do |title|
      job = Job.find_by!(title: title)
      populated = Application.where(job_id: job.id).distinct.pluck(:current_stage_key)
      # Hired fills only when a job has made a hire; every working stage must have someone in it.
      working = job.pipeline.resolved_stages.reject { |stage| stage["type"] == "hired" }.map { |stage| stage["key"] }
      assert_equal working.sort, (working & populated).sort, "#{title} has an empty stage"
    end
    assert_equal Job::STATUSES.sort - [ "archived" ], Job.distinct.pluck(:status).sort
    assert Job.exists?(confidential: true, code_name: "Project Lighthouse")
    assert_includes Job.on_careers("internal").pluck(:title), "Technical Recruiter"
    assert_not_includes Job.on_careers("public").pluck(:title), "Technical Recruiter"
    assert_not_includes Job.on_careers("public").pluck(:title), "VP of Marketing"
  end

  test "anyone past a stage has completed interviews and submitted scorecards behind them" do
    Application.find_each do |app|
      stages = app.pipeline.resolved_stages
      # A hire sits in Hired; judge it by the stage it was hired from.
      key = app.current_stage_key
      if stages.find { |s| s["key"] == key }&.dig("type") == "hired"
        key = StageTransition.where(subject_type: "Application", subject_id: app.id, command: "hire").order(:created_at).last&.from_stage_key
      end
      current = stages.index { |s| s["key"] == key }.to_i
      stages[0...current].each do |stage|
        Array(stage["interviews"]).select { |i| i["required"] != false }.each do |iv|
          interview = Interview.find_by(application_id: app.id, stage_key: stage["key"], interview_key: iv["key"])
          assert interview&.status == "completed" && Scorecard.exists?(interview_id: interview.id, status: "submitted"),
                 "#{app.person.display_name} passed #{stage['key']}/#{iv['key']} without feedback"
        end
      end
    end
  end

  test "a loop that opens with the screen books rounds in order, and finished one-person interviews have feedback" do
    Application.where(status: "active").find_each do |app|
      stages = app.pipeline.resolved_stages
      at = stages.index { |s| s["key"] == app.current_stage_key }
      next unless at
      loop_ivs = Array(stages[at]["interviews"])
      next unless loop_ivs.size > 1 && stages[0...at].none? { |s| Array(s["interviews"]).any? }

      interviews = Interview.where(application_id: app.id, stage_key: app.current_stage_key).index_by(&:interview_key)
      next if interviews.empty?
      fed = interviews.values.select { |i| Scorecard.exists?(interview_id: i.id, status: "submitted") }
      later_booked = loop_ivs.drop(1).filter_map { |iv| interviews[iv["key"]] }.select { |i| i.status == "scheduled" }
      if fed.empty?
        assert_empty later_booked.map(&:interview_key), "#{app.person.display_name} has later #{app.current_stage_key} rounds booked before the screen"
      end
    end
    one_person = Interview.where(status: "completed").select { |i| Array(i.interviewer_user_ids).size == 1 }
    missing = one_person.reject { |i| Scorecard.exists?(interview_id: i.id, status: "submitted") }
    assert_empty missing.map { |i| "#{i.application.person.display_name} #{i.stage_key}/#{i.interview_key}" }, "finished one-person interviews without feedback"
  end

  test "interviews are scheduled sensibly relative to now" do
    assert_equal 0, Interview.where(status: "completed").where("starts_at > ?", Time.current).count
    assert_equal 0, Interview.where(status: "scheduled").where("starts_at < ?", Time.current).count
    assert_operator Interview.where(status: "scheduled").where(starts_at: Time.current..7.days.from_now).count, :>=, 5
    assert_empty Interview.where(status: "scheduled").where.not(starts_at: nil).select { |i| i.starts_at.on_weekend? }
    assert Scorecard.where(status: "draft").exists?, "feedback-owed drafts missing"
    # Stored in UTC but read in the viewer's zone: keep it inside US business hours, no dawn interviews.
    assert_empty Interview.where.not(starts_at: nil).reject { |i| (16..21).cover?(i.starts_at.hour) }.map(&:id)
  end

  test "offers cover every status and every document is a real downloadable file" do
    assert_equal Offer::STATUSES.sort, Offer.distinct.pluck(:status).sort
    assert_empty Document.all.reject { |d| d.file.attached? }
    sample = Document.where(scan_status: "clean").where("filename LIKE '%resume.pdf'").first
    bytes = sample.file.download
    assert bytes.start_with?("%PDF-")
    assert_equal sample.checksum, Digest::SHA256.hexdigest(bytes)
    assert_equal 0, Person.where.not(id: Document.select(:person_id)).count
  end

  test "templates, sequences, sourcing and referrals have content" do
    assert_operator MessageTemplate.active.count, :>=, 18
    assert MessageTemplate.archived.exists?
    assert MessageTemplate.exists?(locale: "de")
    assert_operator Sequence.count, :>=, 6
    assert Sequence.templates.exists?
    assert SequenceEnrollment.exists?(status: "stopped", stop_reason: "replied")
    assert Communication.exists?(direction: "inbound")
    assert_operator Project.count, :>=, 8
    assert ProjectMember.exists?(status: "converted")
    assert_equal %w[converted hired submitted], Referral.distinct.pluck(:status).sort - [ "withdrawn" ]
    assert SourcingTask.exists?(status: "open")
    assert_operator ApplicationQuestionTemplate.count, :>=, 4
    assert_operator OfferTemplate.count, :>=, 5
    assert Requisition.exists?(status: "filled") && Requisition.exists?(status: "pending_approval")
  end

  test "careers flagships and CRM volume look like a real org, not a thin fixture" do
    pe = Job.find_by!(title: "Platform Engineer")
    ae = Job.find_by!(title: "Account Executive")
    assert_operator Application.where(job_id: pe.id, current_stage_key: "applied").count, :>=, 20
    assert_operator Application.where(job_id: ae.id, current_stage_key: "applied").count, :>=, 15
    assert Person.exists?(display_name: "Priya Venkatesh")
    assert Person.exists?(display_name: "Elena Vargas")
    assert_operator Person.count, :>=, 400
    assert Person.where.not(source: [ nil, "" ]).exists?
    assert_operator PersonNote.count, :>=, 80
    assert Sequence.find_by!(key: "alumni-boomerang").status == "active"
    assert_operator SequenceEnrollment.joins(:sequence).where(sequences: { key: "alumni-boomerang" }).count, :>=, 1
    sample = Person.where.not(primary_email: nil).where("primary_email LIKE ?", "%@mail.test").exists? ||
             Person.where("primary_email LIKE ?", "%@inbox.test").exists? ||
             Person.where("primary_email LIKE ?", "%.test").where.not("primary_email LIKE ?", "%@example.%").exists?
    assert sample, "expected non-example.test demo emails"
  end

  test "re-running and forcing the enrichment adds nothing" do
    before = counts
    BigBuckDemoSeed.call(slug: @slug, reset: false)
    assert_equal before, counts
    BigBuckDemoSeed.call(slug: @slug, reset: false, force: true)
    assert_equal before, counts
  end

  test "reset wipes the org including enrichment tables and rebuilds the same shape" do
    before = counts
    rebuilt = BigBuckDemoSeed.call(slug: @slug, reset: true)
    Current.organization_id = rebuilt.organization.id
    @org = rebuilt.organization
    assert_equal before, counts
  end
end
