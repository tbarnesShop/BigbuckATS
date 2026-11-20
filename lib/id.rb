# frozen_string_literal: true

# UUIDv7-style ids (time-ordered). Falls back to SecureRandom when needed.
module Id
  module_function

  def generate
    # 48-bit unix ms + version/variant + random (RFC 9562 UUIDv7 shape)
    now_ms = (Time.now.to_f * 1000).to_i
    bytes = Array.new(16) { rand(256) }
    bytes[0] = (now_ms >> 40) & 0xFF
    bytes[1] = (now_ms >> 32) & 0xFF
    bytes[2] = (now_ms >> 24) & 0xFF
    bytes[3] = (now_ms >> 16) & 0xFF
    bytes[4] = (now_ms >> 8) & 0xFF
    bytes[5] = now_ms & 0xFF
    bytes[6] = (bytes[6] & 0x0F) | 0x70
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    format(
      "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
      *bytes
    )
  end
end
