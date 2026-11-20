# frozen_string_literal: true

require "test_helper"

# M9d: background work runs on a schedule, claims rows safely, retries, and
# cleans data in batches.
class WorkersTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "Worker Co", slug: "work-#{SecureRandom.hex(4)}",
      owner_email: "owner-#{SecureRandom.hex(4)}@work.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    Current.organization_id = @org.id
    Current.actor_id = @provisioned[:user].id
    Current.actor_type = "user"
  end

  teardown do
    WebhookDispatcher.http_client = nil
    GmailClient.backend = nil
    Current.reset
  end

  test "every recurring task names a job that exists" do
    config = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml"))
    tasks = config.fetch("production")
    assert_operator tasks.size, :>=, 8
    tasks.each_value { |task| task["class"]&.constantize }
  end

  test "the relay fans each event out once per matching endpoint" do
    WebhookEndpoint.create!(key: "all", url: "https://hooks.test/all", secret_ref: "s1")
    WebhookEndpoint.create!(key: "jobs", url: "https://hooks.test/jobs", secret_ref: "s2", event_types: %w[job.created])
    ChangeWriter.call(record: Company.new(name: "Relay Co"), action: "company.created", event_type: "company.created")

    assert_operator OutboxRelay.call, :>=, 1
    deliveries = WebhookDelivery.where(event_type: "company.created")
    assert_equal [ "all" ], deliveries.map { |d| WebhookEndpoint.find(d.webhook_endpoint_id).key }
    assert OutboxEvent.where(event_type: "company.created").all?(&:delivered_at)

    OutboxEvent.update_all(delivered_at: nil)
    OutboxRelay.call
    assert_equal 1, WebhookDelivery.where(event_type: "company.created").count, "relay is idempotent"
  end

  test "deliveries carry actor and api version, and failures retry with backoff until they give up" do
    fake = WebhookDispatcher::FakeHttp.new
    WebhookDispatcher.http_client = fake
    WebhookEndpoint.create!(key: "ok", url: "https://hooks.test/ok", secret_ref: "s1")
    ChangeWriter.call(record: Company.new(name: "Hook Co"), action: "company.created", event_type: "company.created")

    delivered = WebhookDispatcher.drain!.select { |d| d.organization_id == @org.id }
    assert_equal [ "delivered" ], delivered.map(&:status).uniq
    body = fake.deliveries.last[:body]
    assert_equal "2026-11-01", body["api_version"]
    assert_equal "user", body.dig("actor", "type")
    assert fake.deliveries.last[:headers]["X-BigBuck-Signature"].present?

    WebhookDispatcher.http_client = WebhookDispatcher::FakeHttp.new(status: 503)
    ChangeWriter.call(record: Company.new(name: "Flaky Co"), action: "company.created", event_type: "company.created")
    OutboxRelay.call
    delivery = WebhookDelivery.where(status: "pending").last
    WebhookDispatcher.deliver_due!
    delivery.reload
    assert_equal "pending", delivery.status
    assert_equal 1, delivery.attempt_count
    assert_operator delivery.next_attempt_at, :>, Time.current
    assert_equal "http_503", delivery.last_error

    (WebhookDispatcher::MAX_ATTEMPTS - 1).times do
      delivery.update_columns(next_attempt_at: 1.second.ago)
      WebhookDispatcher.deliver_due!
      delivery.reload
    end
    assert_equal "failed", delivery.status
    assert_equal WebhookDispatcher::MAX_ATTEMPTS, delivery.attempt_count
  end

  test "webhook URLs that point inside the network are refused" do
    refute SafeHttp.public_address?("10.1.2.3")
    refute SafeHttp.public_address?("169.254.169.254")
    refute SafeHttp.public_address?("127.0.0.1")
    refute SafeHttp.public_address?("::1")
    refute SafeHttp.public_address?("::ffff:192.168.1.1")
    assert SafeHttp.public_address?("8.8.8.8")

    assert_raises(SafeHttp::Refused) { SafeHttp.new.post("http://example.com/x", body: "{}", headers: {}) }
    assert_raises(SafeHttp::Refused) { SafeHttp.new.post("https://localhost/x", body: "{}", headers: {}) }
  end

  test "a wait step pauses a sequence until the worker resumes it" do
    fake = GmailClient::Fake.new
    GmailClient.backend = fake
    mailbox = Mailbox.create!(kind: "personal", email: "sourcer@work.test", user: @provisioned[:user],
                              status: "connected", secret_ref: "sm://personal")
    MessageTemplate.create!(key: "one", message_type: "sequence", subject: "Hi", body: "First")
    MessageTemplate.create!(key: "two", message_type: "sequence", subject: "Again", body: "Second")
    sequence = Sequence.create!(key: "drip", name: "Drip", steps: [
      { "type" => "email", "template_key" => "one" },
      { "type" => "wait", "days" => 2 },
      { "type" => "email", "template_key" => "two" }
    ])
    person = PersonMatcher.find_or_create(display_name: "Prospect", email: "prospect@work.test",
                                          viewer: @provisioned[:membership]).person

    enrollment = SequenceRunner.enroll!(sequence: sequence, person: person, mailbox: mailbox)
    assert_equal 1, fake.sent.size
    assert_in_delta 2.days.from_now, enrollment.reload.next_run_at, 5.seconds

    assert_equal 0, SequenceRunner.tick!
    assert_equal 1, fake.sent.size

    travel 2.days + 1.minute do
      assert_equal 1, SequenceRunner.tick!
    end
    assert_equal 2, fake.sent.size
    assert_equal 3, enrollment.reload.step_index
    assert_nil enrollment.next_run_at
  end

  test "large imports are staged and processed in chunks, matching existing people" do
    existing = PersonMatcher.find_or_create(display_name: "Ada", email: "ada@work.test",
                                            viewer: @provisioned[:membership]).person
    csv = +"id,name,email,phone\n"
    csv << "S-0,Ada Lovelace,ADA@work.test,(610) 555-0100\n"
    (1..4).each { |i| csv << "S-#{i},Person #{i},p#{i}@work.test,\n" }
    csv << "S-5,No Email,,\n"

    result = CsvPeopleImporter.call(csv_string: csv, source_system: "bulk", async: true)
    run = result.run
    assert_equal "queued", run.status
    assert_equal 6, run.import_rows.count
    assert_equal 1, run.error_count
    assert_enqueued_with(job: ProcessImportJob, args: [ run.id ])

    ImportProcessor.new(run, chunk: 2).process!
    run.reload
    assert_equal "applied", run.status
    assert_equal 4, run.created_count
    assert_equal 1, run.updated_count
    assert_equal 6, run.processed_count
    assert_equal existing.id, run.import_rows.find_by(source_id: "S-0").resource_id, "matched by canonical email"
    assert_equal "+16105550100", existing.reload.primary_phone
  end

  test "the cleaner re-keys old contact points and holds collisions for merge" do
    a = Person.create!(display_name: "A")
    b = Person.create!(display_name: "B")
    current = PersonContactPoint.create!(person: a, kind: "phone", value: "610-555-0100")
    assert_equal "+16105550100", current.canonical_key
    # A row keyed by the old digits-only rule, as existing data would be.
    legacy = PersonContactPoint.create!(person: b, kind: "phone", value: "(610) 555 0199")
    legacy.update_columns(value: "(610) 555 0100", normalized_value: "6105550100", canonical_key: "6105550100")

    totals = ContactPointCleaner.call(organization_ids: [ @org.id ])
    assert_equal 1, totals[:held_for_merge]
    legacy.reload
    assert_nil legacy.canonical_key
    assert_equal a.id, legacy.duplicate_of_person_id
    assert MergeSuggestion.exists?(person_a_id: [ a.id, b.id ].min, person_b_id: [ a.id, b.id ].max)
  end

  test "the retention sweep runs across people without raising" do
    Person.create!(display_name: "Retained")
    totals = RetentionSweep.call(organization_ids: [ @org.id ])
    assert_operator totals.values.sum, :>=, 1
    assert_equal 0, totals["error"]
  end
end
