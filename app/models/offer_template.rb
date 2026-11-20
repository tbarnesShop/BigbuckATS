# frozen_string_literal: true

class OfferTemplate < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :key, :name, :body, :format, presence: true
  validates :key, uniqueness: { scope: :organization_id }
end
