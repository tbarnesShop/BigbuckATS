# frozen_string_literal: true

class ApprovalPolicyStep < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :approval_policy

  validates :name, :position, :approvers, :require_mode, presence: true
end
