# frozen_string_literal: true

require "test_helper"

class CustomFieldsGraphqlTest < ActionDispatch::IntegrationTest
  setup do
    @header_auth_was = Rails.configuration.x.header_auth
    Rails.configuration.x.header_auth = false
    @provisioned = OrganizationProvisioner.call(
      name: "CF Graph", slug: "cfg-#{SecureRandom.hex(4)}",
      owner_email: "owner-#{SecureRandom.hex(4)}@cfg.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @owner = @provisioned[:user]
    within_org do
      @person = Person.create!(display_name: "Ada")
      @token = CredentialIssuer.call(kind: "personal", name: "p", user: @owner, scopes: Scopes::ALL, audit: false).token
      @reader = CredentialIssuer.call(kind: "personal", name: "r", user: @owner, scopes: %w[people:read], audit: false).token
    end
  end

  teardown do
    Rails.configuration.x.header_auth = @header_auth_was
    Current.reset
  end

  test "define a field, set a typed value, and read it back through one schema" do
    created = gql(<<~GQL)
      mutation {
        createCustomField(input: { entity: "person", key: "years", label: "Years", fieldType: "number" }) {
          field { id key fieldType version }
          userErrors { code }
        }
      }
    GQL
    field = created.dig("data", "createCustomField", "field")
    assert_equal 1, field["version"]

    set = gql(<<~GQL)
      mutation {
        setCustomFieldValue(input: { entityType: "person", entityId: "#{@person.id}", key: "years", value: { number: 7 } }) {
          value { key fieldVersion ... on CustomFieldNumberValue { number } }
          userErrors { code message }
        }
      }
    GQL
    assert_empty set.dig("data", "setCustomFieldValue", "userErrors")
    assert_equal 7.0, set.dig("data", "setCustomFieldValue", "value", "number")

    bad = gql(<<~GQL)
      mutation {
        setCustomFieldValue(input: { entityType: "person", entityId: "#{@person.id}", key: "years", value: { text: "lots" } }) {
          userErrors { code }
        }
      }
    GQL
    assert_equal "invalid_value", bad.dig("data", "setCustomFieldValue", "userErrors", 0, "code")

    read = gql(<<~GQL)
      { person(id: "#{@person.id}") { customFields { key fieldType ... on CustomFieldNumberValue { number } } } }
    GQL
    assert_equal [ { "key" => "years", "fieldType" => "number", "number" => 7.0 } ], read.dig("data", "person", "customFields")
  end

  test "a type change previews counts and refuses unconvertible values" do
    field = within_org { CustomFieldDefinitions.create!(entity: "person", key: "code", label: "Code", field_type: "text") }
    within_org { CustomFieldValues.write!(entity_type: "Person", entity_id: @person.id, key: "code", value: "abc") }

    preview = gql(%({ customFieldTypeChangePreview(id: "#{field.id}", toType: "number") { total unconvertible } }))
    assert_equal({ "total" => 1, "unconvertible" => 1 }, preview.dig("data", "customFieldTypeChangePreview"))

    refused = gql(<<~GQL)
      mutation { changeCustomFieldType(input: { id: "#{field.id}", toType: "number" }) { field { fieldType } userErrors { code } } }
    GQL
    assert_equal "unconvertible_values", refused.dig("data", "changeCustomFieldType", "userErrors", 0, "code")
  end

  test "managing fields needs custom_field.manage" do
    denied = gql(<<~GQL, token: @reader)
      mutation { createCustomField(input: { entity: "person", key: "x", label: "X", fieldType: "text" }) { userErrors { code } } }
    GQL
    assert_equal "insufficient_permission", denied.dig("errors", 0, "extensions", "code")
  end

  test "fields limited to other roles are not returned" do
    within_org do
      field = CustomFieldDefinitions.create!(entity: "person", key: "comp_band", label: "Band", field_type: "text",
                                             visibility_roles: %w[admin])
      CustomFieldValues.write!(entity_type: "Person", entity_id: @person.id, key: field.key, value: "L5")
    end
    data = gql(%({ person(id: "#{@person.id}") { customFields { key } } customFieldDefinitions(entity: "person") { key } }))
    assert_empty data.dig("data", "person", "customFields")
    assert_empty data.dig("data", "customFieldDefinitions")
  end

  private

  def gql(query, token: @token)
    post "/graphql", params: { query: query }, headers: { "Authorization" => "Bearer #{token}" }, as: :json
    assert_response :success
    response.parsed_body
  end

  def within_org
    Current.organization_id = @org.id
    Current.actor_id = @owner.id
    yield
  ensure
    Current.reset
  end
end
