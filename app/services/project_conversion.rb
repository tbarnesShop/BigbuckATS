# frozen_string_literal: true

class ProjectConversion
  def self.call(member:, job: nil)
    project = member.project
    target_job = job || project.job
    raise ArgumentError, "job required" unless target_job

    ActiveRecord::Base.transaction do
      application = ApplicationCreator.call(job: target_job, person: member.person, source_project_member: member)
      member.update!(converted_application_id: application.id, status: "converted")
      ChangeWriter.call(
        record: application,
        action: "application.created",
        event_type: "application.created",
        payload: { "source_project_member_id" => member.id }
      )
      application
    end
  end
end
