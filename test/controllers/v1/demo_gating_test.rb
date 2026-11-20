# frozen_string_literal: true

require "test_helper"

# Demo-only behavior is gated by Rails.configuration.x.demo_sign_in (on in the
# test environment). These tests flip it off to prove production behavior.
class V1::DemoGatingTest < ActionDispatch::IntegrationTest
  setup do
    GmailClient.backend = GmailClient::Fake.new
    @provisioned = OrganizationProvisioner.call(
      name: "GateCo", slug: "gate-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@gate.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    @person = Person.create!(display_name: "Pat", primary_email: "pat@example.com")
  end

  teardown do
    GmailClient.backend = nil
    Current.reset
  end

  def headers
    {
      "X-Organization-Id" => @org.id,
      "X-Actor-Id" => @user.id,
      "Idempotency-Key" => "k-#{SecureRandom.hex(4)}"
    }
  end

  def with_demo(value)
    previous = Rails.configuration.x.demo_sign_in
    Rails.configuration.x.demo_sign_in = value
    yield
  ensure
    Rails.configuration.x.demo_sign_in = previous
  end

  def problem
    JSON.parse(response.body)
  end

  test "demo: mailbox connect keeps the stub behavior" do
    with_demo(true) do
      post "/v1/mailboxes", params: { mailbox: { email: "ops@unverified.test" } }, headers: headers, as: :json
      assert_response :created
      assert_equal "connected", response.parsed_body["status"]
    end
  end

  test "production: mailbox connect rejects an unverified domain" do
    with_demo(false) do
      post "/v1/mailboxes", params: { mailbox: { email: "ops@unverified.test" } }, headers: headers, as: :json
      assert_response :unprocessable_entity
      assert_equal "unverified_domain", problem["code"]
      assert_equal 0, Mailbox.unscoped.where(email: "ops@unverified.test").count
    end
  end

  test "production: verified domain without a real grant stays pending" do
    GoogleSignIn.verify_domain!(domain: "gate.test")
    with_demo(false) do
      post "/v1/mailboxes", params: { mailbox: { email: "ops@gate.test" } }, headers: headers, as: :json
      assert_response :created
      assert_equal "pending", response.parsed_body["status"]
    end
  end

  test "production: verified domain with a real secret_ref connects" do
    GoogleSignIn.verify_domain!(domain: "gate.test")
    with_demo(false) do
      post "/v1/mailboxes",
           params: { mailbox: { email: "ops@gate.test", secret_ref: "sm://real-grant" } },
           headers: headers, as: :json
      assert_response :created
      assert_equal "connected", response.parsed_body["status"]
    end
  end

  test "production: sending with no connected mailbox fails instead of inventing one" do
    with_demo(false) do
      assert_no_difference -> { Mailbox.unscoped.count } do
        post "/v1/people/#{@person.id}/communications",
             params: { subject: "Hi", body: "Hello" }, headers: headers, as: :json
      end
      assert_response :unprocessable_entity
      assert_equal "invalid_communication", problem["code"]
      assert_match(/mailbox_required/, problem["title"])
    end
  end

  test "demo: sending with no connected mailbox auto-creates the demo mailbox" do
    with_demo(true) do
      post "/v1/people/#{@person.id}/communications",
           params: { subject: "Hi", body: "Hello" }, headers: headers, as: :json
      assert_response :created
      assert_equal 1, Mailbox.unscoped.where(secret_ref: "sm://auto").count
    end
  end

  test "webhook create rejects non-https and private urls" do
    [ "http://hooks.example.test/x", "https://127.0.0.1/x", "https://localhost/x" ].each do |url|
      post "/v1/webhooks",
           params: { webhook: { key: "k-#{SecureRandom.hex(2)}", url: url, event_types: [ "person.created" ] } },
           headers: headers, as: :json
      assert_response :unprocessable_entity, url
      assert_equal "invalid_webhook_url", problem["code"]
    end
  end

  test "webhook create accepts a public https url" do
    post "/v1/webhooks",
         params: { webhook: { key: "ok-#{SecureRandom.hex(2)}", url: "https://hooks.example.test/x", event_types: [ "person.created" ] } },
         headers: headers, as: :json
    assert_response :created
  end
end
