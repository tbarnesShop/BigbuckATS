# frozen_string_literal: true

class Posting < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :job
  belongs_to :question_template, class_name: "ApplicationQuestionTemplate", optional: true
  has_many :applications, dependent: :restrict_with_exception
  validates :title, presence: true, length: { maximum: 255 }
  validates :status, inclusion: { in: %w[draft published archived] }
  validates :audience, inclusion: { in: Job::CAREERS_VISIBILITIES }
  EMPLOYMENT_TYPES = %w[full_time part_time contract internship temporary].freeze
  validates :employment_type, inclusion: { in: EMPLOYMENT_TYPES }, allow_blank: true
  validates :description, length: { maximum: 20_000 }
  validates :location, length: { maximum: 255 }
  before_validation :prepare_form
  before_update { self.version += 1 unless will_save_change_to_version? }
  validate :active_job_when_published

  scope :visible_on_careers, ->(audience) {
    joins(:job).where(status: "published", audience: [ audience, "both" ])
      .where(jobs: { status: "active", confidential: false })
  }

  def visible_to?(audience)
    %w[public internal].include?(audience) && status == "published" && [ audience, "both" ].include?(self.audience) &&
      job.status == "active" && !job.confidential?
  end

  def publish!
    raise ArgumentError, "job must be active" unless job.status == "active"
    update!(status: "published")
  end

  private

  def prepare_form
    self.audience ||= job.careers_visibility if new_record? && job
    self.questions = PostingQuestions.normalize(questions || [])
    self.template_questions = PostingQuestions.normalize(template_questions || [])
    errors.add(:question_template, "must belong to this organization") if question_template && question_template.organization_id != organization_id
  end

  def active_job_when_published
    if status == "published" && (new_record? || will_save_change_to_status?) && job&.status != "active"
      errors.add(:status, "requires an active job")
    end
  end
end
