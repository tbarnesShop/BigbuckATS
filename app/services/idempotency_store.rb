# frozen_string_literal: true

class IdempotencyStore
  Conflict = Class.new(StandardError)

  def self.fetch(key:, request_path:, request_method:)
    raise ArgumentError, "Idempotency-Key required" if key.blank?
    raise Current::TenantRequired if Current.organization_id.blank?

    existing = IdempotencyKey.find_by(key: key)
    if existing
      if existing.request_path != request_path || existing.request_method != request_method
        raise Conflict, "Idempotency-Key reused with a different request"
      end
      return existing
    end

    nil
  end

  def self.store!(key:, request_path:, request_method:, status:, body:)
    IdempotencyKey.create!(
      key: key,
      request_path: request_path,
      request_method: request_method,
      response_status: status,
      response_body: body
    )
  end
end
