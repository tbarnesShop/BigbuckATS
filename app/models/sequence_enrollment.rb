# frozen_string_literal: true

class SequenceEnrollment < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :sequence
  belongs_to :person
  belongs_to :mailbox

  validates :status, presence: true

  def stop!(reason)
    transaction do
      update!(status: "stopped", stop_reason: reason, next_run_at: nil)
      ScheduledMessage.where(sequence_enrollment_id: id, status: "queued")
                      .update_all(status: "cancelled", defer_reason: "enrollment_stopped", updated_at: Time.current)
      SourcingTask.where(sequence_enrollment_id: id, status: "open", pauses_enrollment: true)
                  .update_all(status: "cancelled", updated_at: Time.current)
    end
  end

  def active?
    status == "active"
  end
end
