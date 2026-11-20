# frozen_string_literal: true

require "test_helper"

class V1::OffersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "OfferCo", slug: "offer-#{SecureRandom.hex(3)}",
      owner_email: "owner-#{SecureRandom.hex(2)}@offer.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    template = PipelineTemplate.create!(key: "default", name: "Default", object_type: "job")
    template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    pipeline = Pipeline.build_from_template!(template: template)
    @job = Job.create!(title: "Backend", status: "active", pipeline: pipeline)
    @person = Person.create!(display_name: "Cand One", primary_email: "c1@offer.test")
    @application = ApplicationCreator.call(job: @job, person: @person)
  end

  teardown { Current.reset }

  test "index filters by application and show includes application" do
    offer = Offer.create!(application: @application, status: "draft", version: 1)

    get "/v1/offers",
        params: { application_id: @application.id },
        headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :success
    assert_equal 1, response.parsed_body["data"].size
    assert_equal offer.id, response.parsed_body["data"].first["id"]

    get "/v1/offers/#{offer.id}",
        headers: { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    assert_response :success
    assert_equal @application.id, response.parsed_body.dig("application", "id")
    assert_equal "draft", response.parsed_body["status"]
  end
end
