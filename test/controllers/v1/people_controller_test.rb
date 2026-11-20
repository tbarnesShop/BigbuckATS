# frozen_string_literal: true

require "test_helper"

class V1::PeopleControllerTest < ActionDispatch::IntegrationTest
  setup do
    result = OrganizationProvisioner.call(
      name: "Acme", slug: "acme-#{SecureRandom.hex(4)}",
      owner_email: "owner-#{SecureRandom.hex(4)}@acme.test", owner_name: "Owner"
    )
    @org = result[:organization]
    @user = result[:user]
    Current.reset
  end

  test "create person with tenant header" do
    assert_difference -> { Person.unscoped.where(organization_id: @org.id).count }, 1 do
      post v1_people_path,
           params: { person: { display_name: "Grace Hopper", email: "grace@example.com" } },
           headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id },
           as: :json
    end
    assert_response :created
    assert_operator AuditEvent.unscoped.where(organization_id: @org.id).count, :>=, 1
    assert_operator OutboxEvent.unscoped.where(organization_id: @org.id).count, :>=, 1
  end

  test "create without tenant returns problem+json" do
    post v1_people_path, params: { person: { display_name: "No Org" } }, as: :json
    assert_response :unauthorized
    assert_equal "application/problem+json", response.media_type
    body = JSON.parse(response.body)
    assert_equal "tenant_required", body["code"]
  end

  test "idempotent create returns the same response" do
    headers = {
      "X-Organization-Id" => @org.id,
      "X-Actor-Id" => @user.id,
      "Idempotency-Key" => "ikey-1"
    }
    post v1_people_path, params: { person: { display_name: "Idem", email: "idem@example.com" } }, headers: headers, as: :json
    assert_response :created
    first = JSON.parse(response.body)

    assert_no_difference -> { Person.unscoped.where(organization_id: @org.id).count } do
      post v1_people_path, params: { person: { display_name: "Idem", email: "idem@example.com" } }, headers: headers, as: :json
    end
    assert_response :created
    assert_equal first["id"], JSON.parse(response.body)["id"]
  end
  test "hiring managers can edit visible contacts and company without gaining erasure or restricted access" do
    Current.organization_id = @org.id
    hm = User.create!(email: "manager-#{SecureRandom.hex(4)}@example.test", name: "Manager")
    Membership.create!(user: hm, role: Role.find_by!(key: "hiring_manager"), status: "active")
    person = PersonMatcher.find_or_create(display_name: "Candidate", email: "old@example.test", phone: "6105550101").person
    company = Company.create!(name: "Example company")
    other = PersonMatcher.find_or_create(display_name: "Hidden", email: "hidden@example.test").person
    other.update!(visibility: "restricted")
    token = CredentialIssuer.call(kind: "session", name: "Manager", user: hm, expires_at: 1.hour.from_now, audit: false).token
    Current.reset
    headers = { "Authorization" => "Bearer #{token}" }
    patch "/v1/people/#{person.id}", headers: headers, as: :json,
      params: { person: { display_name: "New name", email: " New@Example.test ", phone: "(610) 555-0102", affiliation: { company_id: company.id, title: "Engineer" } } }
    assert_response :success
    assert_equal "new@example.test", response.parsed_body["primary_email"]
    assert_equal "+16105550102", response.parsed_body["primary_phone"]
    Current.set(organization_id: @org.id) do
      assert_equal 1, person.contact_points.where(kind: "email", primary: true).count
      assert_equal "Engineer", person.affiliations.first.title
    end
    patch "/v1/people/#{person.id}", headers: headers, as: :json,
      params: { person: { do_not_contact: true, email: "forbidden@example.test" } }
    assert_response :forbidden
    Current.set(organization_id: @org.id) do
      assert_equal "new@example.test", person.reload.primary_email
      refute person.do_not_contact
    end
    patch "/v1/people/#{person.id}", headers: headers, as: :json,
      params: { person: { email: "hidden@example.test", phone: "6105559999" } }
    assert_response :unprocessable_entity
    refute_includes response.body, other.id
    Current.set(organization_id: @org.id) { assert_equal "+16105550102", person.reload.primary_phone }
    patch "/v1/people/#{other.id}", headers: headers, params: { person: { email: "new-hidden@example.test" } }, as: :json
    assert_response :not_found
    post "/v1/people/#{person.id}/erase", headers: headers
    assert_response :forbidden
  end

  test "people pages past the first hundred" do
    Current.organization_id = @org.id
    rows = Array.new(105) { |i| { id: SecureRandom.uuid, organization_id: @org.id, display_name: format("Paged %03d", i),
      primary_email: "paged-#{i}-#{SecureRandom.hex(2)}@x.test", lifecycle_stage: "candidate", created_at: Time.current, updated_at: Time.current } }
    Person.insert_all(rows)
    Current.reset
    headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    get "/v1/people", params: { q: "Paged", limit: 50, page: 3, sort: "name" }, headers: headers
    assert_response :success
    assert_equal 105, response.parsed_body.dig("meta", "total")
    assert_equal 5, response.parsed_body["data"].size
    assert_equal "Paged 100", response.parsed_body["data"].first["display_name"]
  end

  test "people list newest first by default" do
    Current.organization_id = @org.id
    old = Person.create!(display_name: "Zz Older", lifecycle_stage: "candidate", created_at: 2.days.ago)
    fresh = Person.create!(display_name: "Aa Newer", lifecycle_stage: "candidate")
    Current.reset
    get "/v1/people", params: { q: "Newer" }, headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_equal fresh.id, response.parsed_body["data"].first["id"]
    get "/v1/people", headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    ids = response.parsed_body["data"].map { |row| row["id"] }
    assert_operator ids.index(fresh.id), :<, ids.index(old.id)
  end
end
