# frozen_string_literal: true

class ApplicationCreator
  def self.call(job:, person:, source_project_member: nil)
    pipeline = job.pipeline
    application = Application.create!(
      job: job,
      person: person,
      pipeline: pipeline,
      pipeline_version: pipeline.version,
      current_stage_key: pipeline.first_stage_key,
      status: "active",
      source_project_member_id: source_project_member&.id
    )
    EnrollmentStopper.call(person: person, reason: "active_application")
    application
  end
end
