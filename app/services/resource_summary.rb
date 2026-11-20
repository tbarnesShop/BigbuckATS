# frozen_string_literal: true

class ResourceSummary
  def self.person(person, fields: %i[id display_name primary_email lifecycle_stage])
    return nil unless person && !person.erased? && person.merged_into_id.nil?
    return nil unless ResourceVisibility.legacy? || PersonVisibility.visible?(person, viewer: ResourceVisibility.viewer)
    person.as_json(only: fields)
  end
  def self.job(job, fields: %i[id title status])
    return nil unless job
    return nil unless ResourceVisibility.legacy? || (Current.principal&.can?("job.read") &&
      (!job.confidential || Current.principal.can?("job.read_confidential")))
    job.as_json(only: fields)
  end
end
