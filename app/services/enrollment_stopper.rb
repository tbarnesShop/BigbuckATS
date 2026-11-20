# frozen_string_literal: true

# One place that ends a person's sequences. Reasons: reply, bounce, do_not_contact,
# active_application, hired. Stopping cancels any queued sends (SequenceEnrollment#stop!).
class EnrollmentStopper
  REASONS = %w[reply bounce do_not_contact active_application hired manual].freeze

  def self.call(person:, reason:)
    raise ArgumentError, "unknown_stop_reason" unless REASONS.include?(reason)

    SequenceEnrollment.where(person_id: person.id, status: "active").find_each { |e| e.stop!(reason) }
  end
end
