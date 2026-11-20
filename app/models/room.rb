# frozen_string_literal: true

class Room < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :key, :name, :resource_email, presence: true
end
