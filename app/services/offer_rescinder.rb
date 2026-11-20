# frozen_string_literal: true

class OfferRescinder
  def self.call(offer:, reason_key:, actor_id: Current.actor_id)
    raise ArgumentError, "reason_required" if reason_key.blank?
    raise ArgumentError, "already_accepted" if offer.status == "accepted"
    raise ArgumentError, "already_rescinded" if offer.status == "rescinded"

    previous = offer.status
    ActiveRecord::Base.transaction do
      Approval.where(entity_id: offer.id, status: "pending").update_all(status: "cancelled")
      offer.assign_attributes(status: "rescinded", rescind_reason_key: reason_key, live_key: nil)
      ChangeWriter.call(
        record: offer,
        action: "offer.rescinded",
        event_type: "offer.rescinded",
        payload: { "reason_key" => reason_key, "actor_id" => actor_id },
        changes: { "status" => [ previous, "rescinded" ] }
      )
      offer
    end
  end
end
