# frozen_string_literal: true

class CompliancePolicy < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :key, :name, :requirements, presence: true
  validates :key, uniqueness: { scope: :organization_id }

  def notices_req = Array((requirements || {})["notices"] || (requirements || {})[:notices])
  def consents_req = Array((requirements || {})["consents"] || (requirements || {})[:consents])
  def blocks_req = Array((requirements || {})["blocks"] || (requirements || {})[:blocks])
end
