# frozen_string_literal: true

# Marks sent offers whose acceptance window has closed as expired.
class OfferExpirer
  def self.call(now: Time.current, limit: 500)
    expired = 0
    Offer.unscoped.where(status: "sent").joins(
      "INNER JOIN offer_versions ov ON ov.id = offers.current_version_id AND ov.organization_id = offers.organization_id"
    ).where("ov.expires_at IS NOT NULL AND ov.expires_at <= ?", now).limit(limit).find_each do |row|
      Current.set(organization_id: row.organization_id, actor_type: "system", source_surface: "automation") do
        expired += 1 if expire!(row.id, now)
      end
    end
    expired
  end

  def self.expire!(offer_id, now)
    Offer.transaction do
      offer = Offer.lock.find(offer_id)
      if offer.status == "sent"
        SignatureRequest.where(offer_version_id: offer.current_version_id, status: %w[sent viewed])
                        .find_each { |request| request.update!(status: "expired") }
        offer.assign_attributes(status: "expired", version: offer.version + 1)
        ChangeWriter.call(
          record: offer, action: "offer.expired", event_type: "offer.expired",
          payload: { "expired_at" => now }, changes: { "status" => %w[sent expired] }
        )
        true
      else
        false
      end
    end
  end

  private_class_method :expire!
end
