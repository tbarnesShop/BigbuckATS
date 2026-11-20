# frozen_string_literal: true

class InterviewerPoolMember < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :interviewer_pool
  belongs_to :user
end
