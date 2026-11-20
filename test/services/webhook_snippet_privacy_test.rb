# frozen_string_literal: true

require "test_helper"

# Receiver responses can echo the event payload, so the stored snippet is
# classified sensitive, cleared when a person is erased, and purged with age.
class WebhookSnippetPrivacyTest < ActiveSupport::TestCase
  # Echoes the person's email from the request body, like a chatty receiver.
  class EchoHttp
    def post(_url, body:, headers:)
      { status: 200, body: "received #{JSON.parse(body).dig("data", "email")}" }
    end
  end

  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "SnipCo", slug: "sn-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@sn.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    Current.organization_id = @org.id
    Current.actor_id = @provisioned[:user].id
    Current.actor_type = "user"

    WebhookEndpoint.create!(
      key: "snip", url: "https://hooks.example.test/events",
      secret_ref: "whsec_test", event_types: %w[person.created]
    )
    @person = Person.create!(display_name: "Sam", primary_email: "sam-#{SecureRandom.hex(2)}@sn.test")
    @other = Person.create!(display_name: "Other", primary_email: "other-#{SecureRandom.hex(2)}@sn.test")
    WebhookDispatcher.http_client = EchoHttp.new
  end

  teardown do
    WebhookDispatcher.http_client = nil
    Current.reset
  end

  def emit(person)
    ChangeWriter.call(
      record: person, action: "person.created", event_type: "person.created",
      payload: { "person_id" => person.id, "email" => person.primary_email },
      changes: { "display_name" => [ nil, person.display_name ] }
    )
  end

  def deliveries_for(person)
    events = OutboxEvent.unscoped.where(organization_id: @org.id)
                        .where("JSON_UNQUOTE(JSON_EXTRACT(payload, '$.person_id')) = ?", person.id).select(:id)
    WebhookDelivery.unscoped.where(organization_id: @org.id, outbox_event_id: events)
  end

  test "response_snippet is classified sensitive" do
    classes = YAML.load_file(Rails.root.join("config/data_classes.yml"))
    assert_equal "sensitive", classes.dig("webhook_deliveries", "response_snippet")
  end

  test "erasing a person clears the snippets of their deliveries and leaves others" do
    emit(@person)
    emit(@other)
    WebhookDispatcher.drain!

    assert_includes deliveries_for(@person).pluck(:response_snippet).join, @person.primary_email
    assert_includes deliveries_for(@other).pluck(:response_snippet).join, @other.primary_email

    PersonEraser.call(person: @person, mode: "delete")

    assert deliveries_for(@person).exists?, "delivery rows are kept for reporting"
    assert deliveries_for(@person).pluck(:response_snippet).all?(&:blank?)
    assert_includes deliveries_for(@other).pluck(:response_snippet).join, @other.primary_email
    assert_empty PersonEraser.verify(@person)
  end

  test "the retention sweep purges old snippets and keeps recent ones" do
    emit(@person)
    emit(@other)
    WebhookDispatcher.drain!
    deliveries_for(@person).update_all(updated_at: 40.days.ago)

    RetentionSweep.call(organization_ids: [ @org.id ])

    assert deliveries_for(@person).pluck(:response_snippet).all?(&:blank?)
    assert_includes deliveries_for(@other).pluck(:response_snippet).join, @other.primary_email
  end
end
