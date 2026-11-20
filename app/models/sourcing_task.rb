# frozen_string_literal: true

# A follow-up for a person: call, LinkedIn touch, email, anything. Sequence task steps create these
# and (by default) pause the enrollment until the task is completed.
class SourcingTask < ApplicationRecord
  include HasUuid
  include TenantScoped

  STATUSES = %w[open completed cancelled].freeze
  TYPES = %w[call linkedin email other].freeze

  belongs_to :person
  belongs_to :sequence_enrollment, optional: true

  validates :title, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :task_type, inclusion: { in: TYPES }

  scope :open_tasks, -> { where(status: "open") }
  scope :overdue, ->(now = Time.current) { open_tasks.where("due_at < ?", now) }

  def open? = status == "open"

  def complete!
    transaction do
      update!(status: "completed", completed_at: Time.current)
      resume_enrollment!
    end
  end

  def cancel!
    update!(status: "cancelled")
  end

  private

  # A task that paused its sequence hands it back when done, so the next step runs on time.
  def resume_enrollment!
    return unless pauses_enrollment && sequence_enrollment

    enrollment = SequenceEnrollment.find(sequence_enrollment_id)
    SequenceRunner.advance!(enrollment) if enrollment.active?
  end
end
