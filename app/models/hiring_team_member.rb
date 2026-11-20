# frozen_string_literal: true

class HiringTeamMember < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :hiring_team
  belongs_to :user

  validates :team_role, presence: true
end
