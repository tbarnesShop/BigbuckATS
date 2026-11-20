# frozen_string_literal: true

require "test_helper"

class V1::SettingsEditsTest < ActionDispatch::IntegrationTest
  setup do
    provisioned = OrganizationProvisioner.call(name: "EditCo", slug: "edit-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@edit.test", owner_name: "Owner")
    @org = provisioned[:organization]
    @user = provisioned[:user]
    @headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    Current.organization_id = @org.id
    Current.actor_id = @user.id
  end

  teardown { Current.reset }

  test "a message template's subject and body can be edited" do
    template = MessageTemplate.create_template!(key: "hello", message_type: "outreach", subject: "Hi", body: "Old body")
    Current.reset
    patch "/v1/message_templates/#{template.id}", params: { message_template: { subject: "Hello {{ person.first_name }}", body: "New body" } },
      headers: @headers, as: :json
    assert_response :success
    assert_equal [ "Hello {{ person.first_name }}", "New body" ], template.reload.values_at(:subject, :body)
  end

  test "a mailbox can be paused, which stops sending, and its cap changed" do
    mailbox = Mailbox.create!(kind: "shared", email: "team@edit.test", status: "connected", secret_ref: "sm://demo")
    Current.reset
    patch "/v1/mailboxes/#{mailbox.id}", params: { mailbox: { status: "paused", daily_cap: 50 } }, headers: @headers, as: :json
    assert_response :success
    assert_equal [ "paused", 50 ], [ response.parsed_body["status"], response.parsed_body["daily_cap"] ]
    Current.organization_id = @org.id
    error = assert_raises(ArgumentError) { mailbox.reload.reserve_send! }
    assert_equal "mailbox_not_connected", error.message
    Current.reset
    patch "/v1/mailboxes/#{mailbox.id}", params: { mailbox: { daily_cap: 0 } }, headers: @headers, as: :json
    assert_response :unprocessable_entity
  end

  test "a webhook's url, events and on/off can be edited, and it lists recent deliveries" do
    post "/v1/webhooks", params: { webhook: { key: "hook", url: "https://hooks.example.com/in" } },
      headers: @headers.merge("Idempotency-Key" => "hook-#{SecureRandom.hex(3)}"), as: :json
    id = response.parsed_body["id"]
    patch "/v1/webhooks/#{id}", params: { webhook: { url: "https://hooks.example.com/v2", event_types: [ "application.hire" ], active: false } },
      headers: @headers, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal [ "https://hooks.example.com/v2", [ "application.hire" ], false, [] ],
      body.values_at("url", "event_types", "active", "recent_deliveries")
    patch "/v1/webhooks/#{id}", params: { webhook: { url: "http://127.0.0.1/internal" } }, headers: @headers, as: :json
    assert_response :unprocessable_entity, "private addresses stay refused"
  end
end
