# frozen_string_literal: true

class ConsentPurpose < ApplicationRecord
  include HasUuid
  include TenantScoped

  BASES = %w[consent legitimate_interest contract legal_obligation].freeze

  validates :key, :label, :lawful_basis, presence: true
  validates :key, uniqueness: { scope: :organization_id }
  validates :lawful_basis, inclusion: { in: BASES }
end
