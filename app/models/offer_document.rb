# frozen_string_literal: true

class OfferDocument < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :offer_version

  validates :kind, presence: true
end
