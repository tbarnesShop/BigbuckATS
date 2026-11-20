# frozen_string_literal: true

require "test_helper"

class V1::PeopleCrmFieldsTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "CrmFields", slug: "cf-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@cf.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    Current.organization_id = @org.id
    Current.actor_id = @provisioned[:user].id
    @headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @provisioned[:user].id }
  end

  teardown { Current.reset }

  def idem = { "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }

  test "create records the source and headline fields; they come back on read" do
    post "/v1/people", params: { person: { display_name: "Gus", email: "gus@example.com", headline: "Staff backend engineer",
      current_title: "Staff Engineer", city: "Philadelphia", time_zone: "America/New_York", source: "event", source_detail: "GopherCon" } },
         headers: @headers.merge(idem), as: :json
    assert_response :created
    body = response.parsed_body
    assert_equal "event", body["source"]
    assert_equal "GopherCon", body["source_detail"]
    assert_equal "Philadelphia", body["city"]
    assert_equal "not_contacted", body["engagement_status"]
  end

  test "an API-created person defaults to sourced" do
    post "/v1/people", params: { person: { display_name: "Hal", email: "hal@example.com" } }, headers: @headers.merge(idem), as: :json
    assert_equal "sourced", response.parsed_body["source"]
  end

  test "update sets headline fields and a manual engagement decision, and rejects bad values" do
    person = PersonMatcher.find_or_create(display_name: "Ida", email: "ida@example.com", viewer: @provisioned[:membership], source: "sourced").person
    patch "/v1/people/#{person.id}", params: { person: { current_title: "VP Eng", engagement_status: "interested" } },
          headers: @headers.merge(idem), as: :json
    assert_response :success
    assert_equal "interested", response.parsed_body["engagement_status"]

    patch "/v1/people/#{person.id}", params: { person: { engagement_status: "do_not_contact" } },
          headers: @headers.merge(idem), as: :json
    assert_response :unprocessable_content

    # Source is not editable through the API at all: the request succeeds and the value is untouched.
    patch "/v1/people/#{person.id}", params: { person: { source: "import" } }, headers: @headers.merge(idem), as: :json
    assert_equal "sourced", person.reload.source
  end

  test "careers applications record the applied source" do
    result = PersonMatcher.find_or_create(display_name: "Jo", email: "jo@example.com", source: "applied")
    assert_equal "applied", result.person.source
  end
end
