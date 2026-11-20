# frozen_string_literal: true

require "test_helper"

class V1::ImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "ImportCo", slug: "imp-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@i.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
  end

  teardown { Current.reset }

  def headers
    {
      "X-Organization-Id" => @org.id,
      "X-Actor-Id" => @user.id,
      "Idempotency-Key" => "k-#{SecureRandom.hex(4)}"
    }
  end

  test "imports people from csv with dry run then apply" do
    csv = <<~CSV
      id,name,email,phone
      SRC-1,Ada Lovelace,ada@import.test,+15550001
    CSV

    post "/v1/imports",
         params: {
           import: {
             entity: "people",
             csv: csv,
             dry_run: true,
             source_system: "cli_test",
             field_mapping: {
               "id" => "source_id",
               "name" => "display_name",
               "email" => "primary_email",
               "phone" => "primary_phone"
             }
           }
         },
         headers: headers, as: :json
    assert_response :created
    assert_equal "dry_run", response.parsed_body["status"]
    assert_equal 0, Person.where(source_system: "cli_test").count

    post "/v1/imports",
         params: {
           import: {
             entity: "people",
             csv: csv,
             dry_run: false,
             source_system: "cli_test",
             field_mapping: {
               "id" => "source_id",
               "name" => "display_name",
               "email" => "primary_email",
               "phone" => "primary_phone"
             }
           }
         },
         headers: headers, as: :json
    assert_response :created
    run_id = response.parsed_body["id"]
    assert_equal "applied", response.parsed_body["status"]
    assert_equal 1, response.parsed_body["created_count"]
    assert_equal 1, Person.where(source_system: "cli_test", source_id: "SRC-1").count

    get "/v1/imports/#{run_id}", headers: headers
    assert_response :success
    assert_equal 1, response.parsed_body["rows"].size

    get "/v1/imports", headers: headers
    assert_response :success
    assert response.parsed_body["data"].any? { |r| r["id"] == run_id }
  end
end
