# frozen_string_literal: true

require "test_helper"

class V1::ApplicationFormTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "FormCo", slug: "fm-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(2)}@fm.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
  end

  teardown { Current.reset }

  def headers
    { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
  end

  def patch_fields(fields)
    patch "/v1/application_form", params: { application_form: { required_fields: fields } }, headers: headers, as: :json
  end

  test "defaults to name and email, lists the standard fields, no screening questions" do
    get "/v1/application_form", headers: headers
    assert_response :success
    assert_equal %w[display_name email], response.parsed_body["required_fields"]
    assert_includes response.parsed_body["standard_fields"], "phone"
    assert_equal [], response.parsed_body["screening_questions"]
  end

  test "an update changes the required fields and persists" do
    patch_fields(%w[display_name email phone linkedin])
    assert_response :success
    assert_equal %w[display_name email phone linkedin], response.parsed_body["required_fields"]

    get "/v1/application_form", headers: headers
    assert_equal %w[display_name email phone linkedin], response.parsed_body["required_fields"]
  end

  test "duplicates are dropped" do
    patch_fields(%w[display_name email email])
    assert_response :success
    assert_equal %w[display_name email], response.parsed_body["required_fields"]
  end

  test "name and email can never be made optional" do
    patch_fields(%w[display_name phone])
    assert_response :unprocessable_entity
    assert_equal "invalid_application_form", JSON.parse(response.body)["code"]
    assert_match(/always_required:email/, JSON.parse(response.body)["title"])
  end

  test "unknown fields are refused" do
    patch_fields(%w[display_name email ssn])
    assert_response :unprocessable_entity
    assert_match(/unknown_fields:ssn/, JSON.parse(response.body)["title"])
  end

  test "a body without required_fields is refused" do
    patch "/v1/application_form", params: { application_form: {} }, headers: headers, as: :json
    assert_response :unprocessable_entity
    assert_match(/required_fields_missing/, JSON.parse(response.body)["title"])
  end
end
