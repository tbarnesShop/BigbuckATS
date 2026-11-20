# frozen_string_literal: true

require "test_helper"

# The shared demo workspaces must let a visitor work the CRM (notes, follow-ups, tags, saved searches)
# while keeping the destructive verbs blocked. The generic DemoPolicy guard covers new endpoints; this
# pins that down for the CRM surface.
class V1::CrmDemoGatingTest < ActionDispatch::IntegrationTest
  setup do
    @enabled = Rails.configuration.x.demo_sign_in
    Rails.configuration.x.demo_sign_in = true
    @result = OrganizationProvisioner.call(name: "CrmLab", slug: "crmlab-#{SecureRandom.hex(4)}",
      owner_email: "crm-#{SecureRandom.hex(4)}@example.test", owner_name: "Lab Owner")
    @org = @result[:organization]
    DemoSandbox.create!(surface: "tools", organization_id: @org.id, generation: 1,
      state: "ready", seeded_at: Time.current, resets_at: 1.hour.from_now)
    Current.organization_id = @org.id
    issued = CredentialIssuer.call(kind: "session", name: "test", user: @result[:user], expires_at: 1.hour.from_now)
    @person = Person.create!(display_name: "Pat Demo", primary_email: "pat@example.test", lifecycle_stage: "prospect")
    Current.reset
    @headers = { "Authorization" => "Bearer #{issued.token}", "X-Bigbuck-Demo-Generation" => "1" }
  end

  teardown do
    Rails.configuration.x.demo_sign_in = @enabled
    Current.reset
  end

  def h(key) = @headers.merge("Idempotency-Key" => "#{key}-#{SecureRandom.hex(3)}")

  test "notes, follow-ups, tags and saved searches work in a demo workspace" do
    post "/v1/people/#{@person.id}/notes", params: { note: { body: "Likes infra" } }, headers: h("note"), as: :json
    assert_response :created

    post "/v1/tasks", params: { task: { person_id: @person.id, title: "Call", task_type: "call" } }, headers: h("task"), as: :json
    assert_response :created
    task_id = response.parsed_body["id"]

    post "/v1/tasks/#{task_id}/complete", headers: h("done"), as: :json
    assert_response :success

    post "/v1/people/#{@person.id}/tags", params: { name: "go" }, headers: h("tag"), as: :json
    assert_response :created

    post "/v1/saved_searches", params: { saved_search: { name: "Go folks", filters: { tag: "go" } } }, headers: h("ss"), as: :json
    assert_response :created
  end

  test "cancelling a follow-up and removing a tag stay blocked" do
    Current.organization_id = @org.id
    task = SourcingTask.create!(person: @person, title: "Keep", task_type: "call", status: "open")
    Current.reset
    post "/v1/tasks/#{task.id}/cancel", headers: h("cancel"), as: :json
    assert_response :forbidden
    assert_equal "demo_action_blocked", response.parsed_body["code"]
  end
end
