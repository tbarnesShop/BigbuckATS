# frozen_string_literal: true

require "test_helper"

class V1::OutreachAnalyticsTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "AnaCo", slug: "an-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@an.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@an.test", provider: "sandbox",
      status: "connected", secret_ref: "sandbox://mailbox", user: @user)
    @person = PersonMatcher.find_or_create(display_name: "Pat", email: "pat@an.test", viewer: @provisioned[:membership]).person
  end

  teardown { Current.reset }

  def headers
    { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id, "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }
  end

  test "reclassifying a reply updates the person, and unsubscribe opts out" do
    comm = InboundIngestor.call(mailbox: @mailbox, from: "pat@an.test", subject: "Re: hi", body: "Thanks.", provider_message_id: "pm-1")
    assert_equal "other", comm.classification
    patch "/v1/communications/#{comm.id}", params: { communication: { classification: "interested" } }, headers: headers, as: :json
    assert_response :success
    assert_equal "interested", @person.reload.engagement_status
    patch "/v1/communications/#{comm.id}", params: { communication: { classification: "unsubscribe" } }, headers: headers, as: :json
    assert @person.reload.do_not_contact
    patch "/v1/communications/#{comm.id}", params: { communication: { classification: "bounce" } }, headers: headers, as: :json
    assert_response :unprocessable_entity
  end

  test "outreach and snapshot endpoints" do
    get "/v1/analytics/outreach", headers: headers
    assert_response :success
    assert_equal 0, response.parsed_body["contacted"]
    OutreachSnapshotter.call(day: Date.current)
    get "/v1/analytics/outreach_snapshots", headers: headers
    assert_response :success
    assert_equal 1, response.parsed_body["data"].size
    get "/v1/analytics/outreach", params: { from: "2026-02-01", to: "2026-01-01" }, headers: headers
    assert_response :unprocessable_entity
  end
end
