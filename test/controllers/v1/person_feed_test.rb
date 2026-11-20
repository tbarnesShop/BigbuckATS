# frozen_string_literal: true

require "test_helper"

class V1::PersonFeedTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "FeedCo", slug: "f-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@f.test", owner_name: "Owner Person"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    @headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@f.test", provider: "sandbox", status: "connected",
      secret_ref: "sandbox://mailbox", user: @user)
    @person = PersonMatcher.find_or_create(display_name: "Fiona O'Brien", email: "fiona@example.com",
      viewer: @provisioned[:membership]).person
    @person.update!(current_title: "Staff Engineer", city: "Philadelphia")
  end

  teardown { Current.reset }

  def idem = { "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }

  test "preview renders the template with this person's fields and does not send" do
    post "/v1/people/#{@person.id}/preview_message",
         params: { template_key: "starter-intro", subject: "Hi {{person.first_name}} - {{person.current_title}}", mailbox_id: @mailbox.id },
         headers: @headers.merge(idem), as: :json
    assert_response :success
    assert_equal "Hi Fiona - Staff Engineer", response.parsed_body["subject"]
    assert_includes response.parsed_body["body"], "Fiona O'Brien"
    refute_includes response.parsed_body["body"], "&#39;"
    assert_equal 0, SandboxMessage.count
  end

  test "an unknown merge field is refused with the field named" do
    post "/v1/people/#{@person.id}/preview_message", params: { subject: "Hi {{person.shoe_size}}", body: "x" },
         headers: @headers.merge(idem), as: :json
    assert_response :unprocessable_content
    assert_includes response.parsed_body["title"], "person.shoe_size"
  end

  test "one-off send from a template, then a threaded reply, appear in one feed with notes and tasks" do
    post "/v1/people/#{@person.id}/communications", params: { template_key: "starter-intro", mailbox_id: @mailbox.id },
         headers: @headers.merge(idem), as: :json
    assert_response :created
    first = response.parsed_body
    assert_includes first["body"], "Fiona O'Brien"

    sent = SandboxMessage.find_by!(direction: "outbound")
    SandboxInbox.answer!(message: sent, kind: "reply")
    post "/v1/people/#{@person.id}/notes", params: { note: { body: "Replied fast" } }, headers: @headers.merge(idem), as: :json
    post "/v1/tasks", params: { task: { person_id: @person.id, title: "Call Fiona", task_type: "call" } },
         headers: @headers.merge(idem), as: :json
    post "/v1/people/#{@person.id}/tags", params: { name: "go" }, headers: @headers.merge(idem), as: :json

    inbound = Communication.find_by!(person_id: @person.id, direction: "inbound")
    post "/v1/people/#{@person.id}/communications",
         params: { subject: "Re: hello", body: "Great, how is Tuesday?", mailbox_id: @mailbox.id,
                   thread_id: inbound.thread_id, in_reply_to: inbound.rfc822_message_id },
         headers: @headers.merge(idem), as: :json
    assert_response :created

    get "/v1/people/#{@person.id}/feed", headers: @headers
    assert_response :success
    kinds = response.parsed_body["data"].map { |i| i["kind"] }
    assert_equal %w[email email email note task tag].sort, (kinds - [ "event" ]).sort
    emails = response.parsed_body["data"].select { |i| i["kind"] == "email" }
    assert_equal 1, emails.map { |e| e["thread_id"] }.uniq.size, "all three emails share a thread"
    assert_equal "Owner Person", response.parsed_body["data"].find { |i| i["kind"] == "note" }["author"]
    assert_equal %w[outbound inbound outbound].sort, emails.map { |e| e["direction"] }.sort
  end

  test "a person the caller cannot see has no feed" do
    hidden = Person.create!(display_name: "Hidden", visibility: "confidential")
    get "/v1/people/#{hidden.id}/feed", headers: @headers.merge("X-Actor-Id" => SecureRandom.uuid)
    assert_includes [ 403, 404 ], response.status
  end
end
