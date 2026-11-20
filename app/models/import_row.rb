# frozen_string_literal: true

class ImportRow < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :import_run

  validates :row_number, :status, presence: true
end
