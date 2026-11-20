# frozen_string_literal: true

# Surfaces past applicants / silver medalists who are not currently active on a job.
class TalentRediscovery
  Signal = Struct.new(:person, :score, :reasons, :past_applications, keyword_init: true)

  def self.call(job:, viewer:, limit: 50)
    new(job: job, viewer: viewer, limit: limit).call
  end

  def initialize(job:, viewer:, limit:)
    @job = job
    @viewer = viewer
    @limit = [ [ limit.to_i, 1 ].max, 100 ].min
  end

  def call
    active_person_ids = Application.where(job_id: @job.id, status: "active").pluck(:person_id)
    visible = PersonVisibility.scope_for(@viewer).not_merged.not_erased
                              .where.not(id: active_person_ids)

    past = ResourceVisibility.applications.where(person_id: visible.select(:id))
                      .where.not(status: "active")
                      .includes(:person, :job)
                      .order(updated_at: :desc)
                      .limit(500)

    by_person = past.group_by(&:person_id)
    scored = by_person.map { |_pid, apps| score(apps) }.compact
    scored.sort_by { |s| [ -s.score, s.person.display_name.to_s ] }.first(@limit)
  end

  private

  def score(apps)
    person = apps.first.person
    return nil unless person

    reasons = []
    score = 0

    same_job = apps.select { |a| a.job_id == @job.id }
    if same_job.any?
      score += 50
      reasons << "prior_application_same_job"
      score += 20 if same_job.any? { |a| a.status == "rejected" }
      reasons << "silver_medalist" if same_job.any? { |a| a.status == "rejected" }
    end

    other = apps.reject { |a| a.job_id == @job.id }
    if other.any?
      score += 10
      reasons << "past_applicant_other_job"
      title_tokens = @job.title.to_s.downcase.split(/\W+/).reject { |t| t.length < 3 }
      if title_tokens.any? && other.any? { |a| title_overlap?(a.job&.title, title_tokens) }
        score += 25
        reasons << "similar_job_title"
      end
    end

    if person.lifecycle_stage.in?(%w[employee alumni])
      score += 5
      reasons << person.lifecycle_stage
    end

    return nil if score.zero?

    Signal.new(person: person, score: score, reasons: reasons.uniq, past_applications: apps.first(5))
  end

  def title_overlap?(title, tokens)
    hay = title.to_s.downcase
    tokens.any? { |t| hay.include?(t) }
  end
end
