# frozen_string_literal: true

# Delivers webhook rows created by OutboxRelay. Deliveries are claimed with a
# short lease (so a crashed worker's rows are retried), sent outside any lock,
# and retried with exponential backoff until MAX_ATTEMPTS.
class WebhookDispatcher
  MAX_ATTEMPTS = 8
  LEASE = 5.minutes
  BASE_BACKOFF = 30.seconds
  MAX_BACKOFF = 6.hours

  class << self
    attr_writer :http_client

    def http_client
      @http_client || default_http_client
    end

    def default_http_client
      Rails.env.test? ? NullHttp : SafeHttp.new
    end

    # Relay pending outbox events, then deliver everything due. Used by the
    # admin drain endpoint and tests; workers run the two halves separately.
    def drain!(limit: 100, organization_id: nil)
      OutboxRelay.call(organization_id: organization_id)
      deliver_due!(limit: limit, organization_id: organization_id)
    end

    def deliver_due!(limit: 100, now: Time.current, organization_id: nil)
      claim!(limit, now, organization_id).map { |delivery| new.deliver!(delivery) }
    end

    def backoff(attempt)
      [ BASE_BACKOFF * (2**(attempt - 1)), MAX_BACKOFF ].min + rand(0..15).seconds
    end

    private

    def claim!(limit, now, organization_id = nil)
      WebhookDelivery.transaction do
        rows = WebhookDelivery.unscoped.where(status: %w[pending sending])
                              .where("next_attempt_at <= ?", now)
                              .order(:next_attempt_at).limit(limit)
                              .lock("FOR UPDATE SKIP LOCKED")
        rows = rows.where(organization_id: organization_id) if organization_id
        rows = rows.to_a
        WebhookDelivery.unscoped.where(id: rows.map(&:id))
                       .update_all(status: "sending", next_attempt_at: now + LEASE, updated_at: now)
        rows
      end
    end
  end

  def deliver!(delivery)
    endpoint = WebhookEndpoint.unscoped.find_by(id: delivery.webhook_endpoint_id)
    event = OutboxEvent.unscoped.find_by(id: delivery.outbox_event_id)
    return finish!(delivery, status: "failed", error: "endpoint_or_event_missing") unless endpoint&.active && event

    body = {
      "id" => event.id,
      "type" => event.event_type,
      "api_version" => event.api_version,
      "created_at" => event.created_at,
      "actor" => { "type" => event.actor_type, "id" => event.actor_id, "surface" => event.source_surface },
      "data" => event.payload
    }.to_json
    secret = endpoint.signing_secret
    return finish!(delivery, status: "failed", error: "signing_key_rotation_required") if secret.blank?
    timestamp = Time.current.to_i.to_s
    signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")
    headers = {
      "Content-Type" => "application/json",
      "X-BigBuck-Signature" => signature,
      "X-BigBuck-Timestamp" => timestamp,
      "X-BigBuck-Event-Id" => event.id,
      "X-BigBuck-Delivery" => delivery.id
    }

    response = if DemoSandbox.for_organization(delivery.organization_id)
                 { status: 200, body: "Captured locally by the interactive lab; no external request sent." }
    else
                 self.class.http_client.post(endpoint.url, body: body, headers: headers)
    end
    status = response[:status].to_i
    if status.between?(200, 299)
      finish!(delivery, status: "delivered", response_status: status, snippet: response[:body])
    else
      retry_or_fail!(delivery, response_status: status, snippet: response[:body], error: "http_#{status}")
    end
  rescue SafeHttp::Refused, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError,
         SystemCallError, OpenSSL::SSL::SSLError, IOError => e
    retry_or_fail!(delivery, error: "#{e.class.name}: #{e.message}".first(250))
  end

  private

  def finish!(delivery, status:, response_status: nil, snippet: nil, error: nil)
    now = Time.current
    delivery.update_columns(
      status: status, attempt_count: delivery.attempt_count + 1, response_status: response_status,
      response_snippet: snippet.to_s.first(200).presence, last_error: error, next_attempt_at: nil,
      delivered_at: (now if status == "delivered"), updated_at: now
    )
    delivery
  end

  def retry_or_fail!(delivery, response_status: nil, snippet: nil, error: nil)
    attempt = delivery.attempt_count + 1
    return finish!(delivery, status: "failed", response_status: response_status, snippet: snippet, error: error) if attempt >= MAX_ATTEMPTS

    delivery.update_columns(
      status: "pending", attempt_count: attempt, response_status: response_status,
      response_snippet: snippet.to_s.first(200).presence, last_error: error,
      next_attempt_at: Time.current + self.class.backoff(attempt), updated_at: Time.current
    )
    delivery
  end

  module NullHttp
    module_function

    def post(*) = { status: 500, body: "no http client" }
  end

  # In-memory receiver for tests / local proving.
  class FakeHttp
    attr_reader :deliveries

    def initialize(status: 200)
      @deliveries = []
      @status = status
    end

    def post(url, body:, headers:)
      payload = JSON.parse(body)
      @deliveries << { url: url, body: payload, headers: headers }
      { status: @status, body: "ok" }
    end

    def events_of_type(type)
      @deliveries.select { |d| d[:body]["type"] == type }
    end

    def person_ids_from_created
      events_of_type("person.created").filter_map { |d| d[:body].dig("data", "person_id") || d[:body].dig("data", "id") }
    end
  end
end
