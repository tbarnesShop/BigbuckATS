# frozen_string_literal: true

require "test_helper"

# Release gate: end-to-end narrative via domain services (web app is a thin client over this).
class ReleaseGateTest < ActiveSupport::TestCase
  setup do
    GmailClient.backend = GmailClient::Fake.new
    CalendarClient.backend = CalendarClient::Fake.new
    WebhookDispatcher.http_client = WebhookDispatcher::FakeHttp.new
  end

  teardown do
    GmailClient.backend = nil
    CalendarClient.backend = nil
    WebhookDispatcher.http_client = nil
    Current.reset
  end

  test "release gate narrative completes" do
    provisioned = OrganizationProvisioner.call(
      name: "GateCo", slug: "gate-#{SecureRandom.hex(3)}",
      owner_email: "owner-#{SecureRandom.hex(2)}@gate.test", owner_name: "Owner"
    )
    Current.organization_id = provisioned[:organization].id
    Current.actor_id = provisioned[:user].id
    org = provisioned[:organization]
    org.update!(settings: { "offers_hire_on_accept" => true, "hire_requires_accepted_offer" => true })
    GoogleSignIn.verify_domain!(domain: "gate.test")
    assert GoogleSignIn.allow?(email: "owner@gate.test")

    WebhookEndpoint.create!(key: "wh", url: "https://hooks.test/e", secret_ref: "sec")
    csv = "id,name,email\nP1,Prospect One,p1@gate.test\n"
    imported = CsvPeopleImporter.call(
      csv_string: csv,
      field_mapping: { "id" => "source_id", "name" => "display_name", "email" => "primary_email" },
      source_system: "csv"
    )
    prospect = imported.people.first

    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [
      { "key" => "applied", "name" => "Applied", "type" => "apply" },
      { "key" => "onsite", "name" => "Onsite", "type" => "interview",
        "interviews" => [ { "key" => "hm", "name" => "HM", "required" => true } ] },
      { "key" => "offer", "name" => "Offer", "type" => "offer" }
    ])
    pipeline = Pipeline.build_from_template!(template: template)
    job = Job.create!(title: "Platform Eng", status: "active", pipeline: pipeline)
    department = provisioned[:dimensions][:department]
    dept_head = User.create!(email: "head@gate.test", name: "Dept Head")
    eng = DimensionValue.create!(
      dimension: department, key: "engineering", label: "Engineering",
      attributes_json: { "head" => dept_head.id }
    )
    EntityDimensionValue.create!(entity_type: "Job", entity_id: job.id, dimension: department, dimension_value: eng)

    mailbox = Mailbox.create!(kind: "personal", email: "sourcer@gate.test", user_id: provisioned[:user].id, status: "connected", secret_ref: "v:1")
    shared = Mailbox.create!(kind: "shared", email: "recruiting@gate.test", status: "connected", secret_ref: "v:2")
    MessageTemplate.create!(key: "intro", subject: "Hi {{ person.display_name }}", body: "Hello", message_type: "outreach")
    sequence = Sequence.create!(key: "outreach", name: "Outreach", steps: [ { "type" => "email", "template_key" => "intro" } ])
    enrollment = SequenceRunner.enroll!(sequence: sequence, person: prospect, mailbox: mailbox)
    outreach = Communication.find_by!(person_id: prospect.id, direction: "outbound")
    MailSync.ingest_inbound!(
      mailbox: mailbox, from: prospect.primary_email, subject: "Re: Hi",
      body: "Interested", thread_id: outreach.thread_id, provider_message_id: "reply_1"
    )
    assert_equal "stopped", enrollment.reload.status

    project_template = PipelineTemplate.create!(key: "sourcing", name: "Sourcing", object_type: "project")
    project_template.publish!(stages: [ { "key" => "prospect", "name" => "Prospect", "type" => "review" } ])
    project_pipeline = Pipeline.build_from_template!(template: project_template, scope: "project")
    project = Project.create!(name: "Pool", pipeline: project_pipeline, job: job)
    member = ProjectMember.create!(
      project: project, person: prospect, pipeline: project_pipeline,
      pipeline_version: project_pipeline.version, current_stage_key: "prospect", status: "active"
    )
    application = ProjectConversion.call(member: member)
    MessageSender.send_now!(mailbox: shared, person: prospect, subject: "Confirm", body: "Interview soon", message_type: "confirmation")

    hm = User.create!(email: "hm@gate.test", name: "HM")
    profiles = [ { user_id: hm.id, paused: false } ]
    booking = PanelBooking.suggest_and_book!(
      application: application,
      interview_defs: [ { key: "hm", duration_minutes: 30, count: 1, candidate_user_ids: [ hm.id ] } ],
      profiles: profiles,
      organizer_calendar: "recruiting@gate.test",
      user_emails: { hm.id => hm.email },
      search_start: Time.utc(2026, 11, 2, 9, 0, 0),
      search_end: Time.utc(2026, 11, 6, 17, 0, 0)
    )
    assert booking.booked
    ScorecardSubmitter.call(interview: booking.interviews.first, user: hm, rating: "yes")

    ApprovalPolicy.create!(
      key: "eng-offers", name: "Eng", applies_to: "offer", priority: 10,
      conditions: { "job.dimensions.department" => "engineering" }
    ).tap do |p|
      ApprovalPolicyStep.create!(
        approval_policy: p, position: 1, name: "Dept head",
        mode: "sequential",
        approvers: [ "attribute:job.dimensions.department.head" ],
        require_mode: "all", if_no_approver: "block"
      )
    end
    ApprovalPolicy.create!(key: "default-offers", name: "Default", applies_to: "offer", priority: 0, is_catch_all: true)

    offer = OfferSubmitter.create_draft!(application: application, fields: { "base-salary" => 175_000 })
    OfferSubmitter.submit!(offer: offer)
    approval = Approval.find_by!(entity_id: offer.id, status: "pending")
    OfferApprover.approve!(approval: approval, actor_id: dept_head.id)
    offer.reload
    letter = OfferTemplate.create!(key: "us", name: "US", body: "Hi {{ candidate.display_name }} — {{ job.title }} at {{ offer.fields.base-salary }}")
    sent = OfferSender.call(offer: offer, template: letter, to_email: prospect.primary_email)
    accepted = OfferAcceptance.accept!(token: sent.token, ip_address: "127.0.0.1", user_agent: "gate", typed_name: "Prospect One")
    assert accepted.hired
    assert_equal "hired", application.reload.status

    WebhookDispatcher.drain!
    sync = SyncFeed.people
    assert sync["data"].any? { |row| row["id"] == prospect.id }

    PersonEraser.call(person: prospect.reload, mode: "delete")
    assert_empty PersonEraser.verify(prospect)
  end
end
