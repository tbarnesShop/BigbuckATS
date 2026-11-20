# frozen_string_literal: true

class ConfigRevision < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :number, :source, :manifest_hash, :manifest, presence: true
  validates :number, uniqueness: { scope: :organization_id }
end
