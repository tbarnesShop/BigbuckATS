# frozen_string_literal: true

class ApprovalPolicy < ApplicationRecord
  include HasUuid
  include TenantScoped

  has_many :steps, class_name: "ApprovalPolicyStep", dependent: :destroy

  validates :key, :name, :applies_to, presence: true
  validates :key, uniqueness: { scope: :organization_id }
end
