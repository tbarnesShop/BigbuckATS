# frozen_string_literal: true

class ConfigPlan < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :status, :desired_manifest, :manifest_hash, presence: true
  validate { errors.add(:change_set, "must be an array") unless change_set.is_a?(Array) }
  validates :object_versions, presence: true, allow_blank: true

  def applied?
    status == "applied"
  end
end
