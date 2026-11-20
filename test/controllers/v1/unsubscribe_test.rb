# frozen_string_literal: true

require "test_helper"

class V1::UnsubscribeTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "UnsubCo", slug: "u-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@u.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    @person = PersonMatcher.find_or_create(display_name: "Una", email: "una@example.com",
      viewer: @provisioned[:membership]).person
    @token = UnsubscribeToken.issue(@person)
  end

  teardown { Current.reset }

  test "the link needs no credential and shows a masked address" do
    get "/v1/public/unsubscribe/#{@token}"
    assert_response :success
    assert_equal "u***@example.com", response.parsed_body["email_hint"]
    assert_equal false, response.parsed_body["already_unsubscribed"]
  end

  test "posting opts the person out, stops sequences, and is idempotent" do
    mailbox = Mailbox.create!(kind: "shared", email: "r@u.test", provider: "sandbox", status: "connected",
      secret_ref: "sandbox://mailbox")
    enrollment = SequenceRunner.enroll!(sequence: Sequence.find_by!(key: "starter-outreach"), person: @person, mailbox: mailbox)

    2.times do
      post "/v1/public/unsubscribe/#{@token}"
      assert_response :success
    end
    assert @person.reload.do_not_contact
    assert_equal "do_not_contact", enrollment.reload.stop_reason
    assert_equal 1, OptOut.where(person_id: @person.id).count
  end

  test "a forged token is rejected" do
    post "/v1/public/unsubscribe/nope"
    assert_response :unprocessable_content
  end
end
