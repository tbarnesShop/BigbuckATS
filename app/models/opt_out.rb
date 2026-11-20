# frozen_string_literal: true

# Suppression list. Keyed by a digest of the normalized address so the opt-out
# outlives the person record (erasure) without storing the address.
class OptOut < ApplicationRecord
  include HasUuid
  include TenantScoped

  SOURCES = %w[unsubscribe_link reply manual import].freeze

  belongs_to :person, optional: true

  validates :source, inclusion: { in: SOURCES }
  validates :email_digest, presence: true

  def self.digest(email)
    Digest::SHA256.hexdigest(email.to_s.strip.downcase)
  end

  def self.blocked?(email)
    return false if email.blank?

    exists?(email_digest: digest(email))
  end

  # Records the opt-out, flags the person do-not-contact and stops their sequences.
  def self.add!(person:, source:)
    email = person.primary_email
    row = find_or_create_by!(email_digest: digest(email)) do |opt|
      opt.person_id = person.id
      opt.source = source
    end
    person.update!(do_not_contact: true) unless person.do_not_contact
    EnrollmentStopper.call(person: person, reason: "do_not_contact")
    row
  end
end
