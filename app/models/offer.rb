# frozen_string_literal: true

class Offer < ApplicationRecord
  include HasUuid
  include TenantScoped

  STATUSES = %w[
    draft pending_approval changes_requested approved sent
    accepted declined expired rescinded
  ].freeze

  belongs_to :application
  has_many :offer_versions, dependent: :destroy
  belongs_to :current_version, class_name: "OfferVersion", optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }

  before_validation :assign_live_key

  private

  def assign_live_key
    self.live_key = status == "rescinded" ? nil : application_id
  end
end
