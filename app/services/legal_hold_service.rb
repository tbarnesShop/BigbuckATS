# frozen_string_literal: true

class LegalHoldService
  def self.place!(subject:, reason:, actor_id: Current.actor_id)
    LegalHold.create!(
      subject_type: subject.class.name.underscore,
      subject_id: subject.id,
      reason: reason,
      placed_by_user_id: actor_id,
      placed_at: Time.current
    )
  end

  def self.release!(hold:, actor_id: Current.actor_id)
    hold.update!(released_by_user_id: actor_id, released_at: Time.current)
    hold
  end

  def self.held_person_ids
    holds = LegalHold.active.to_a
    person_ids = holds.select { |h| h.subject_type == "person" }.map(&:subject_id)
    app_ids = holds.select { |h| h.subject_type == "application" }.map(&:subject_id)
    job_ids = holds.select { |h| h.subject_type == "job" }.map(&:subject_id)
    person_ids |= Application.where(id: app_ids).pluck(:person_id) if app_ids.any?
    person_ids |= Application.where(job_id: job_ids).pluck(:person_id) if job_ids.any?
    person_ids.uniq
  end

  def self.person_held?(person_id)
    held_person_ids.include?(person_id)
  end
end
