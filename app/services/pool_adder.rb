# frozen_string_literal: true

# Adds people to a pool (sourcing project), skipping people already in it.
class PoolAdder
  def self.call(project:, people:, added_by_user_id: Current.actor_id)
    pipeline = project.pipeline
    existing = ProjectMember.where(project_id: project.id).pluck(:person_id).to_set
    added = []
    people.each do |person|
      next if existing.include?(person.id)

      member = ProjectMember.create!(
        project: project, person: person, pipeline: pipeline, pipeline_version: pipeline&.version,
        current_stage_key: pipeline&.first_stage_key, status: "active", version: 1, added_by_user_id: added_by_user_id
      )
      ChangeWriter.call(
        record: member, action: "project_member.added", event_type: "project_member.added",
        payload: { "project_id" => project.id, "person_id" => person.id }
      )
      added << member
    end
    { "added" => added.size, "already_members" => people.size - added.size,
      "member_count" => ProjectMember.where(project_id: project.id, status: "active").count }
  end
end
