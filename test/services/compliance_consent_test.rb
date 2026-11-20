# frozen_string_literal: true

require "test_helper"

# M7a proving test: EU applicant sees EU notice and cannot apply without consent;
# a message is blocked until the policy's consent exists.
class ComplianceConsentTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "CompCo", slug: "cp-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@cp.test", owner_name: "O"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id

    @processing = ConsentPurpose.create!(
      key: "data-processing", label: "Data processing", lawful_basis: "consent"
    )
    @outreach = ConsentPurpose.create!(
      key: "outreach", label: "Outreach", lawful_basis: "consent"
    )

    @eu_notice = Notice.create!(key: "privacy-notice-eu", name: "EU privacy")
    @eu_notice.publish!(locale: "en", body: "EU English privacy notice text")
    @eu_notice.publish!(locale: "de", body: "EU Deutsche Datenschutzhinweise")

    @fallback_notice = Notice.create!(key: "privacy-notice", name: "Default privacy")
    @fallback_notice.publish!(locale: "en", body: "Default privacy notice")

    CompliancePolicy.create!(
      key: "eu-candidates", name: "EU", priority: 20, is_fallback: false,
      conditions: { "candidate.location.region" => %w[eu eea] },
      requirements: {
        "notices" => [ { "notice" => "privacy-notice-eu", "show" => [ "apply-form" ] } ],
        "consents" => [
          { "purpose" => "data-processing", "collect" => "apply-form", "required" => true }
        ],
        "blocks" => [
          { "action" => "communication.send", "unless" => { "consent" => "outreach" } }
        ]
      }
    )
    CompliancePolicy.create!(
      key: "everyone-else", name: "Default", priority: 0, is_fallback: true,
      conditions: {},
      requirements: {
        "notices" => [ { "notice" => "privacy-notice", "show" => [ "apply-form" ] } ],
        "consents" => [
          { "purpose" => "data-processing", "collect" => "apply-form", "required" => true }
        ],
        "blocks" => []
      }
    )

    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    @pipeline = Pipeline.build_from_template!(template: template)
    @job = Job.create!(title: "Eng", status: "active", pipeline: @pipeline)
  end

  teardown { Current.reset }

  test "EU applicant is shown EU notice in their language and cannot apply without consent" do
    person = Person.create!(
      display_name: "Hans", primary_email: "hans@cp.test",
      country: "DE", region: "eu"
    )

    req = ApplyCompliance.requirements(person: person, job: @job, locale: "de")
    assert_equal 1, req.notices.size
    assert_equal "privacy-notice-eu", req.notices.first[:notice].key
    assert_includes req.notices.first[:version].body, "Deutsche"
    assert_equal [ "data-processing" ], req.required_consents.map { |c| c[:purpose].key }

    assert_raises(ApplyCompliance::MissingConsent) do
      ApplyCompliance.apply!(
        person: person, job: @job, locale: "de",
        granted_purpose_keys: [], ip_address: "203.0.113.5"
      )
    end

    application = ApplyCompliance.apply!(
      person: person, job: @job, locale: "de",
      granted_purpose_keys: [ "data-processing" ],
      ip_address: "203.0.113.5", user_agent: "Test/1.0"
    )
    assert application.persisted?
    assert NoticeReceipt.exists?(person_id: person.id, shown_via: "apply_form")
    consent = Consent.current_for(person_id: person.id, purpose_id: @processing.id)
    assert consent.granted?
    assert_equal "de", consent.evidence_json["locale"]
  end

  test "message is blocked until the consent a policy names exists" do
    GmailClient.backend = GmailClient::Fake.new
    person = Person.create!(
      display_name: "Marie", primary_email: "marie@cp.test",
      country: "FR", region: "eu"
    )
    mailbox = Mailbox.create!(
      kind: "shared", email: "recruiting@cp.test", status: "connected", secret_ref: "vault:x"
    )

    error = assert_raises(ConsentGate::Blocked) do
      MessageSender.send_now!(
        mailbox: mailbox, person: person,
        subject: "Hi", body: "Hello"
      )
    end
    assert_match(/outreach/, error.message)

    Consent.create!(
      person: person, consent_purpose: @outreach, lawful_basis: "consent",
      status: "granted", captured_via: "recorded_by_user",
      captured_at: Time.current, created_at: Time.current
    )
    communication = MessageSender.send_now!(
      mailbox: mailbox, person: person,
      subject: "Hi", body: "Hello"
    )
    assert_equal "sent", communication.status
  ensure
    GmailClient.backend = nil
  end
end
