# frozen_string_literal: true

class StageTransition < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :subject_type, :subject_id, :to_stage_key, :command, presence: true
end
