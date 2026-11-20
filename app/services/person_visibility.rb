# frozen_string_literal: true

# Architecture rule 3 (simplified for M1 before applications/projects exist):
# - org-wide person.read sees public people
# - person.read_restricted sees restricted/confidential/private
# - scoped memberships only see people tagged with their dimension values (or public with no tags yet stays visible to org-wide only)
# - someone booked onto an interview can open the candidate they are interviewing, whatever their
#   scope or the person's visibility: an assignment that asks for feedback must let them read who
#   it is about (the same rule that lets a named approver read the offer). That opens the one
#   record; it does not add the person to lists or search.
class PersonVisibility
  def self.visible?(person, viewer:)
    return false if person.nil? || person.merged_into_id.present? || person.erased_at.present?
    return true if viewer.nil? == false && viewer_is_platform?(viewer)

    membership = membership_for(viewer)
    return false unless membership&.permission?("person.read")
    return true if interviewing_person_ids(membership).include?(person.id)

    return false if person.restricted? && !membership.permission?("person.read_restricted")

    return true if membership.org_wide?

    entity_in_scope?(person, membership)
  end

  def self.can_see_both?(a, b, viewer:)
    visible?(a, viewer: viewer) && visible?(b, viewer: viewer)
  end

  def self.scope_for(viewer)
    membership = membership_for(viewer)
    return Person.none unless membership&.permission?("person.read")

    scoped_people(membership)
  end

  def self.scoped_people(membership)
    base = Person.visible_catalog
    base = base.where(visibility: "public") unless membership.permission?("person.read_restricted")
    return base if membership.org_wide?

    value_ids = scoped_value_ids(membership)
    return Person.none if value_ids.empty?

    tagged_ids = EntityDimensionValue.where(
      entity_type: "Person",
      dimension_value_id: value_ids
    ).select(:entity_id)

    base.where(id: tagged_ids)
  end

  # Applications this member is booked to interview on. Empty for org-wide members who already read
  # restricted people (nothing to add), and for agents. The grant is to that record only: the
  # candidate opens (visible?, ResourceVisibility.applications) but does not join people lists,
  # search or bulk actions (scope_for).
  def self.interviewing_application_ids(viewer)
    membership = membership_for(viewer)
    return Interview.none.select(:application_id) unless membership&.permission?("person.read")
    return Interview.none.select(:application_id) if membership.org_wide? && membership.permission?("person.read_restricted")

    user_id = membership.try(:interviewer_user_id)
    return Interview.none.select(:application_id) if user_id.blank?

    Interview.where.not(status: "cancelled")
             .where("JSON_CONTAINS(interviewer_user_ids, ?)", user_id.to_json)
             .select(:application_id)
  end

  def self.interviewing_person_ids(membership)
    Application.where(id: interviewing_application_ids(membership)).distinct.pluck(:person_id)
  end

  def self.membership_for(viewer)
    case viewer
    when Membership, PrincipalViewer then viewer
    when User
      Membership.find_by(user_id: viewer.id, status: "active")
    else
      nil
    end
  end

  def self.viewer_is_platform?(_viewer)
    false
  end

  def self.entity_in_scope?(person, membership)
    value_ids = scoped_value_ids(membership)
    return false if value_ids.empty?

    EntityDimensionValue.where(
      entity_type: "Person",
      entity_id: person.id,
      dimension_value_id: value_ids
    ).exists?
  end

  def self.scoped_value_ids(membership)
    membership.membership_scopes.flat_map do |scope|
      if scope.include_descendants
        scope.dimension_value.self_and_descendant_ids
      else
        [ scope.dimension_value_id ]
      end
    end.uniq
  end
end
