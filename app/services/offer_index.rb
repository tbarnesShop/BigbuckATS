# frozen_string_literal: true

# Offer hub list. `counts` is the status breakdown of the application filter
# (or the whole org) before the status filter, so badges stay stable while
# `rows` follows `status`.
class OfferIndex
  def self.call(application_id: nil, status: nil)
    scope = Current.principal ? ResourceVisibility.offers : Offer.all
    scope = scope.where(application_id: application_id) if application_id.present?
    counts = Offer::STATUSES.index_with { 0 }
    scope.group(:status).count.each { |key, total| counts[key] = total if counts.key?(key) }
    if status.present?
      raise ArgumentError, "unknown_status:#{status}" unless Offer::STATUSES.include?(status)

      scope = scope.where(status: status)
    end
    { rows: scope.includes(:application, :current_version).order(:created_at).limit(100).to_a, counts: counts }
  end
end
