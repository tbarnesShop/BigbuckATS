# frozen_string_literal: true

# Keyed hashing for personal values in audit history. Plain SHA-256 of an email
# can be reversed by hashing a list of emails; an HMAC with a server-side key,
# salted by organization, cannot. The key comes from AUDIT_HASH_KEY or is derived
# from secret_key_base (already in Secret Manager in production).
module AuditHasher
  module_function

  def key
    @key ||= ENV["AUDIT_HASH_KEY"].presence || Rails.application.key_generator.generate_key("bigbuck.audit_hash.v1", 32)
  end

  def reset_key!
    @key = nil
  end

  def digest(organization_id, value)
    return nil if value.nil?

    text = value.is_a?(String) ? value : value.to_json
    OpenSSL::HMAC.hexdigest("SHA256", key, "#{organization_id}:#{text}")
  end
end
