# frozen_string_literal: true

class HiringTeam < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :job
  has_many :members, class_name: "HiringTeamMember", dependent: :destroy
end
