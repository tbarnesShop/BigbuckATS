# frozen_string_literal: true

# Offer versions are classified sensitive as a whole. Unknown/custom offer
# fields stay protected too, rather than relying on an incomplete salary list.
class OfferFieldPolicy
  def self.read(fields, authorized: false)
    authorized ? (fields || {}) : {}
  end
  def self.for_current(fields)
    read(fields, authorized: ResourceVisibility.legacy? || Current.principal&.can?("offer.view_compensation"))
  end
end
