# frozen_string_literal: true

class InterviewerPool < ApplicationRecord
  include HasUuid
  include TenantScoped

  has_many :members, class_name: "InterviewerPoolMember", dependent: :destroy

  validates :key, :name, presence: true
end
