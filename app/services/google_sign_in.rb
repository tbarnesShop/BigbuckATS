# frozen_string_literal: true

# Verified-domain Google sign-in gate (OmniAuth wiring later).
class GoogleSignIn
  Error = Class.new(StandardError)
  DomainNotVerified = Class.new(Error)

  def self.allow?(email:, organization: nil)
    org = organization || Organization.find(Current.organization_id)
    domain = email.to_s.split("@", 2).last&.downcase
    raise ArgumentError, "invalid_email" if domain.blank?

    verified = VerifiedDomain.within_organization(org.id).exists?(domain: domain, status: "verified")
    raise DomainNotVerified, domain unless verified

    true
  end

  def self.verify_domain!(domain:)
    record = VerifiedDomain.find_or_initialize_by(domain: domain.to_s.downcase)
    record.status = "verified"
    record.verified_at = Time.current
    record.save!
    record
  end
end
