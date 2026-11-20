# frozen_string_literal: true

class ImportRun < ApplicationRecord
  include HasUuid
  include TenantScoped

  has_many :import_rows, dependent: :destroy

  validates :source, :entity, :status, :field_mapping, presence: true
end
