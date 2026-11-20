require "test_helper"

class SecurityBoundariesTest < ActionDispatch::IntegrationTest
  setup do
    @header = Rails.configuration.x.header_auth
    Rails.configuration.x.header_auth = false
    data = OrganizationProvisioner.call(name: "Security", slug: "security-#{SecureRandom.hex(4)}",
      owner_email: "security-#{SecureRandom.hex(4)}@example.test", owner_name: "Owner")
    @org = data[:organization]
    @owner = data[:user]
    Current.organization_id = @org.id
    @token = CredentialIssuer.call(kind: "session", name: "Security", user: @owner).token
    @person = Person.create!(display_name: "Synthetic private name", primary_email: "private@example.test")
    Current.reset
  end
  teardown do
    Rails.configuration.x.header_auth = @header
    Current.reset
  end

  test "operational logs exclude form values and query strings" do
    stream = StringIO.new
    old_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(stream, level: Logger::INFO)
    post "/v1/people?probe=private-query-text", params: { person: { display_name: "Synthetic secret", email: "private-log@example.test" } },
      headers: { "Authorization" => "Bearer #{@token}" }, as: :json
    assert_response :created
    %w[private-query-text Synthetic private-log@example.test].each { |value| refute_includes stream.string, value }
    assert_equal "private, no-store", response.headers["Cache-Control"]
  ensure
    Rails.logger = old_logger
  end

  test "untrusted request bodies are bounded before JSON parsing" do
    post "/v1/people", params: "x" * (RequestSecurity::MAX_BODY + 1), headers: { "Content-Type" => "application/json" }
    assert_response :content_too_large
  end

  test "with an edge secret set, only requests carrying it reach Rails (health check stays open)" do
    reached = []
    middleware = RequestSecurity.new(->(env) { reached << env["PATH_INFO"]; [ 200, {}, [ "ok" ] ] })
    request = ->(path, header = nil) do
      env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => path, "rack.input" => StringIO.new("") }
      env["HTTP_X_BIGBUCK_EDGE"] = header if header
      middleware.call(env).first
    end
    with_env("BIGBUCK_EDGE_SECRET" => "s3cret-value") do
      assert_equal 403, request.call("/demo/sandboxes/ui")
      assert_equal 403, request.call("/v1/people", "wrong")
      assert_equal 403, request.call("/v1/people", "s3cret-valu")
      assert_equal 200, request.call("/v1/people", "s3cret-value")
      assert_equal 200, request.call("/up")
    end
    with_env("BIGBUCK_EDGE_SECRET" => nil) { assert_equal 200, request.call("/v1/people") }
    assert_equal %w[/v1/people /up /v1/people], reached
  end

  def with_env(values)
    saved = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "oversized bodies cannot bypass limits with safe HTTP verbs" do
    middleware = RequestSecurity.new(->(_env) { flunk "oversized input reached Rails" })
    %w[GET HEAD OPTIONS].each do |method|
      status, = middleware.call("REQUEST_METHOD" => method,
        "rack.input" => StringIO.new("x" * (RequestSecurity::MAX_BODY + 1)))
      assert_equal 413, status
    end
  end

  test "tenant role relationships reject a cross-tenant database write" do
    other = OrganizationProvisioner.call(name: "Other", slug: "other-#{SecureRandom.hex(4)}",
      owner_email: "other-#{SecureRandom.hex(4)}@example.test", owner_name: "Other")
    Current.set(organization_id: @org.id) do
      membership = Membership.find_by!(user_id: @owner.id)
      assert_raises(ActiveRecord::InvalidForeignKey) { membership.update_columns(role_id: other[:membership].role_id) }
    end
  end

  test "webhook secrets are encrypted unique and timestamp signatures verify" do
    Current.set(organization_id: @org.id) do
      first = WebhookEndpoint.create!(key: "first", url: "https://hooks.example.test", event_types: [ "security.test" ])
      second = WebhookEndpoint.create!(key: "second", url: "https://hooks.example.test")
      refute_equal first.signing_secret, second.signing_secret
      refute_includes first.secret_ref, first.signing_secret
      old = first.signing_secret
      first.rotate_signing_secret!
      refute_equal old, first.signing_secret
      event = OutboxEvent.create!(event_type: "security.test", resource_type: "Person", resource_id: @person.id, payload: { "person_id" => @person.id })
      delivery = WebhookDelivery.create!(webhook_endpoint: first, outbox_event_id: event.id, event_type: event.event_type,
        status: "pending", attempt_count: 0)
      fake = WebhookDispatcher::FakeHttp.new
      WebhookDispatcher.http_client = fake
      WebhookDispatcher.new.deliver!(delivery)
      sent = fake.deliveries.first
      timestamp = sent[:headers]["X-BigBuck-Timestamp"]
      expected = OpenSSL::HMAC.hexdigest("SHA256", first.signing_secret, "#{timestamp}.#{sent[:body].to_json}")
      assert_equal expected, sent[:headers]["X-BigBuck-Signature"]
    end
  ensure
    WebhookDispatcher.http_client = nil
  end

  test "same idempotency key cannot replay a changed request or a newly hidden person" do
    headers = { "Authorization" => "Bearer #{@token}", "Idempotency-Key" => "same" }
    post "/v1/people", params: { person: { display_name: "First" } }, headers: headers, as: :json
    assert_response :created
    id = response.parsed_body["id"]
    post "/v1/people", params: { person: { display_name: "Other" } }, headers: headers, as: :json
    assert_response :conflict
    Current.set(organization_id: @org.id) { Person.find(id).update!(erased_at: Time.current) }
    post "/v1/people", params: { person: { display_name: "First" } }, headers: headers, as: :json
    assert_response :conflict
  end
end
