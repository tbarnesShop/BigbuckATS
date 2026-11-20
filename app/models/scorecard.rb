# frozen_string_literal: true

class Scorecard < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :interview
  belongs_to :user

  validates :status, presence: true
end
