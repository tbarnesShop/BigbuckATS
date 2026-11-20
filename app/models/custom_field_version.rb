# frozen_string_literal: true

class CustomFieldVersion < ApplicationRecord
  include HasUuid
  include TenantScoped

  CHANGE_KINDS = %w[created updated type_changed archived restored].freeze

  belongs_to :custom_field

  validates :version, :change_kind, :definition, presence: true
  validates :change_kind, inclusion: { in: CHANGE_KINDS }
end
