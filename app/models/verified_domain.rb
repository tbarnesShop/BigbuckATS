# frozen_string_literal: true

class VerifiedDomain < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :domain, :status, presence: true
  validates :domain, uniqueness: { scope: :organization_id }
end
