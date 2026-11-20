# frozen_string_literal: true

# Idempotency keys only need to outlive client retries; they also cache API
# responses that can contain personal data, so they are deleted after a day.
class PurgeIdempotencyKeysJob < ApplicationJob
  queue_as :maintenance
  TTL = 24.hours

  def perform
    loop do
      deleted = IdempotencyKey.unscoped.where("created_at < ?", TTL.ago).limit(1_000).delete_all
      break if deleted < 1_000
    end
  end
end
