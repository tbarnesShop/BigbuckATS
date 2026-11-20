# frozen_string_literal: true

class InterviewerBlock < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :user

  validates :starts_at, :ends_at, presence: true
end
