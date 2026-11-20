# frozen_string_literal: true

require "test_helper"

class V1::CareersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dataset = BigBuckDataset.call(slug: "big-buck-careers-#{SecureRandom.hex(3)}")
    @org = @dataset.organization
    Current.reset
  end

  teardown { Current.reset }

  test "public careers includes configurable hero photo and active jobs" do
    get "/v1/public/careers/#{@org.slug}"
    assert_response :success
    body = response.parsed_body
    assert_equal "Big Buck", body.dig("organization", "name")
    assert_equal "/careers-canopy.avif", body.dig("careers", "hero_image_url")
    assert_equal "Open roles", body.dig("careers", "headline")
    titles = body.fetch("jobs").map { |j| j["title"] }
    assert_includes titles, "Platform Engineer"
    assert_includes titles, "Account Executive"
  end

  test "organization update can change careers hero image url" do
    patch "/v1/organizations/#{@org.id}",
          params: {
            organization: {
              careers_hero_image_url: "https://cdn.example.com/hero.jpg",
              careers_headline: "Join the canopy",
              careers_subcopy: "Engineering and sales."
            }
          },
          headers: {
            "X-Organization-Id" => @org.id,
            "X-Actor-Id" => @dataset.users.fetch("admin").id
          },
          as: :json
    assert_response :success
    assert_equal "https://cdn.example.com/hero.jpg", response.parsed_body.dig("careers", "hero_image_url")
    assert_equal "Join the canopy", response.parsed_body.dig("careers", "headline")

    get "/v1/public/careers/#{@org.slug}"
    assert_equal "https://cdn.example.com/hero.jpg", response.parsed_body.dig("careers", "hero_image_url")
  end

  test "careers sections, highlights and accent are configurable and public" do
    headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @dataset.users.fetch("admin").id }
    get "/v1/public/careers/#{@org.slug}"
    assert_nil response.parsed_body.dig("careers", "about")
    assert_nil response.parsed_body.dig("careers", "accent_color")

    patch "/v1/organizations/#{@org.id}",
          params: { organization: {
            careers_about_title: "One record.", careers_about_body: "Same person, same API.",
            careers_culture_title: "Remote by default.", careers_accent_color: "#2ec4b6",
            careers_culture: [ { title: "Agents welcome", body: "MCP for every role." } ]
          } },
          headers: headers, as: :json
    assert_response :success

    get "/v1/public/careers/#{@org.slug}"
    careers = response.parsed_body.fetch("careers")
    assert_equal({ "title" => "One record.", "body" => "Same person, same API." }, careers["about"])
    assert_equal "Remote by default.", careers.dig("culture_intro", "title")
    assert_equal "#2ec4b6", careers["accent_color"]
    assert_equal [ { "title" => "Agents welcome", "body" => "MCP for every role." } ], careers["culture"]

    patch "/v1/organizations/#{@org.id}",
          params: { organization: { careers_accent_color: "red; background:url(x)" } },
          headers: headers, as: :json
    assert_response :unprocessable_entity
  end
end
