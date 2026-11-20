# frozen_string_literal: true

class InterviewerProfile < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :user

  validates :time_zone, :working_hours, presence: true
end
