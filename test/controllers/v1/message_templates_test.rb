# frozen_string_literal: true

require "test_helper"

class V1::MessageTemplatesTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "TplCo", slug: "tp-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@tp.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
  end

  teardown { Current.reset }

  def headers
    { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id, "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }
  end

  def create_template(key, locale: nil, subject: "Hi", body: "Hello")
    attrs = { key: key, message_type: "outreach", subject: subject, body: body, locale: locale }.compact
    post "/v1/message_templates", params: { message_template: attrs }, headers: headers, as: :json
  end

  def keys(status = nil)
    get "/v1/message_templates", params: status ? { status: status } : {}, headers: headers
    assert_response :success
    # New orgs ship starter templates; these tests are about the ones they create.
    response.parsed_body["data"].reject { |row| row["key"].start_with?("starter-") }.map { |row| [ row["key"], row["locale"] ] }
  end

  test "create defaults the locale to en" do
    create_template("welcome")
    assert_response :created
    assert_equal "en", response.parsed_body["locale"]
    assert_nil response.parsed_body["archived_at"]
  end

  test "the same key and locale cannot be created twice, another locale can" do
    create_template("welcome")
    create_template("welcome")
    assert_response :unprocessable_entity
    assert_equal "invalid_message_template", JSON.parse(response.body)["code"]
    assert_match(/key_taken/, JSON.parse(response.body)["title"])

    create_template("welcome", locale: "fr")
    assert_response :created
  end

  test "a template needs a subject" do
    create_template("no-subject", subject: "")
    assert_response :unprocessable_entity
    assert_equal "validation_failed", JSON.parse(response.body)["code"]
  end

  test "lists active templates by default, ordered by key then locale" do
    create_template("b-key")
    create_template("a-key", locale: "fr")
    create_template("a-key")
    assert_equal [ %w[a-key en], %w[a-key fr], %w[b-key en] ], keys
  end

  test "archiving hides a template from the default list and is reversible by status filter" do
    create_template("old")
    create_template("new")
    get "/v1/message_templates", headers: headers
    old_id = response.parsed_body["data"].find { |row| row["key"] == "old" }["id"]

    post "/v1/message_templates/#{old_id}/archive", headers: headers, as: :json
    assert_response :success
    assert response.parsed_body["archived_at"].present?

    assert_equal [ %w[new en] ], keys
    assert_equal [ %w[old en] ], keys("archived")
    assert_equal [ %w[new en], %w[old en] ], keys("all")
  end

  test "archiving twice is refused" do
    create_template("once")
    id = response.parsed_body["id"]
    post "/v1/message_templates/#{id}/archive", headers: headers, as: :json
    assert_response :success
    post "/v1/message_templates/#{id}/archive", headers: headers, as: :json
    assert_response :unprocessable_entity
    assert_match(/already_archived/, JSON.parse(response.body)["title"])
  end

  test "an unknown status filter is refused" do
    get "/v1/message_templates", params: { status: "bogus" }, headers: headers
    assert_response :unprocessable_entity
  end
end
