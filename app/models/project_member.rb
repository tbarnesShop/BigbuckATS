# frozen_string_literal: true

class ProjectMember < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :project
  belongs_to :person
  belongs_to :pipeline, optional: true

  validates :status, presence: true

  def stage_transitions
    StageTransition.where(subject_type: "ProjectMember", subject_id: id).order(:created_at)
  end
end
