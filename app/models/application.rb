# frozen_string_literal: true

class Application < ApplicationRecord
  include HasUuid
  include TenantScoped

  STATUSES = %w[active rejected withdrawn hired].freeze

  belongs_to :posting, optional: true
  belongs_to :job
  belongs_to :person
  belongs_to :pipeline

  validates :current_stage_key, :status, :pipeline_version, presence: true
  validates :status, inclusion: { in: STATUSES }

  def stage_transitions
    StageTransition.where(subject_type: "Application", subject_id: id).order(:created_at)
  end
end
