# frozen_string_literal: true

# Signed, non-expiring token for the unsubscribe link (an unsubscribe link must keep working).
class UnsubscribeToken
  PURPOSE = "unsubscribe"

  def self.issue(person)
    verifier.generate({ "person_id" => person.id, "organization_id" => person.organization_id }, purpose: PURPOSE)
  end

  def self.verify(token)
    payload = verifier.verify(token, purpose: PURPOSE)
    person = Person.within_organization(payload.fetch("organization_id")).find_by(id: payload.fetch("person_id"))
    raise ArgumentError, "unknown_person" unless person

    person
  rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError
    raise ArgumentError, "invalid_token"
  end

  def self.verifier
    Rails.application.message_verifier("bigbuck.unsubscribe")
  end

  def self.web_url(token)
    "#{ENV.fetch('BIGBUCK_WEB_URL', 'http://127.0.0.1:44100').chomp('/')}/unsubscribe/#{token}"
  end

  def self.api_url(token)
    "#{ENV.fetch('BIGBUCK_API_URL', 'http://127.0.0.1:3000').chomp('/')}/v1/public/unsubscribe/#{token}"
  end
end
