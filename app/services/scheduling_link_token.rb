# frozen_string_literal: true

# Link id signed with the app secret — nothing secret stored on the row.
class SchedulingLinkToken
  PURPOSE = "scheduling_link"

  def self.issue(link)
    verifier.generate({ "id" => link.id, "organization_id" => link.organization_id }, purpose: PURPOSE, expires_in: link.expires_at - Time.current)
  end

  def self.verify(token)
    payload = verifier.verify(token, purpose: PURPOSE)
    org_id = payload.fetch("organization_id")
    link = SchedulingLink.within_organization(org_id).find_by(id: payload.fetch("id"))
    raise ArgumentError, "unknown_link" unless link
    raise ArgumentError, "unusable_link" unless link.usable?

    link
  rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError
    raise ArgumentError, "invalid_token"
  end

  def self.verifier
    Rails.application.message_verifier("bigbuck.scheduling")
  end
end
