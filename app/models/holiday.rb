# frozen_string_literal: true

class Holiday < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :name, :observed_on, presence: true
end
