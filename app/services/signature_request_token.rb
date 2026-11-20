# frozen_string_literal: true

class SignatureRequestToken
  PURPOSE = "offer_signature"

  def self.issue(request)
    verifier.generate(
      { "id" => request.id, "organization_id" => request.organization_id },
      purpose: PURPOSE,
      expires_in: [ request.expires_at - Time.current, 1.minute ].max
    )
  end

  def self.verify(token)
    payload = verifier.verify(token, purpose: PURPOSE)
    request = SignatureRequest.within_organization(payload.fetch("organization_id")).find_by(id: payload.fetch("id"))
    raise ArgumentError, "unknown_request" unless request
    raise ArgumentError, "unusable_request" unless request.usable?

    request
  rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError
    raise ArgumentError, "invalid_token"
  end

  def self.verifier
    Rails.application.message_verifier("bigbuck.offer_signature")
  end
end
