# frozen_string_literal: true

class OutreachSnapshot < ApplicationRecord
  include HasUuid
  include TenantScoped

  ORG = "org"

  validates :snapshot_on, :scope_key, :metrics, presence: true
end
