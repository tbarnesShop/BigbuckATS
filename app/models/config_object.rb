# frozen_string_literal: true

class ConfigObject < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :kind, :key, :spec, :version, :status, presence: true
  validates :key, uniqueness: { scope: %i[organization_id kind] }

  def identity
    "#{kind}/#{key}"
  end
end
