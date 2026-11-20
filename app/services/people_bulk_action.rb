# frozen_string_literal: true

# Bulk CRM actions over a set of people ids (already visibility-checked by caller filters).
class PeopleBulkAction
  ACTIONS = %w[enroll_sequence set_dnc clear_dnc add_to_project tag untag].freeze

  def self.call(viewer:, action:, person_ids:, params: {})
    new(viewer: viewer, action: action, person_ids: person_ids, params: params).call
  end

  def initialize(viewer:, action:, person_ids:, params:)
    @viewer = viewer
    @action = action.to_s
    @person_ids = Array(person_ids).uniq
    @params = params.deep_stringify_keys
  end

  def call
    raise ArgumentError, "unknown_action" unless ACTIONS.include?(@action)
    raise ArgumentError, "person_ids_required" if @person_ids.empty?
    raise ArgumentError, "too_many_people" if @person_ids.size > 200

    people = PersonVisibility.scope_for(@viewer).where(id: @person_ids).to_a
    results = people.map { |person| run_one(person) }
    { "action" => @action, "results" => results }
  end

  private

  def run_one(person)
    case @action
    when "enroll_sequence"
      enroll(person)
    when "set_dnc"
      person.update!(do_not_contact: true, do_not_contact_reason: @params["reason"].presence || "manual")
      { "person_id" => person.id, "ok" => true }
    when "clear_dnc"
      person.update!(do_not_contact: false, do_not_contact_reason: nil)
      { "person_id" => person.id, "ok" => true }
    when "add_to_project"
      add_to_project(person)
    when "tag"
      PersonTagger.add!(person: person, tag: bulk_tag)
      { "person_id" => person.id, "ok" => true }
    when "untag"
      PersonTagger.remove!(person: person, tag: bulk_tag)
      { "person_id" => person.id, "ok" => true }
    end
  rescue StandardError => e
    { "person_id" => person.id, "ok" => false, "error" => e.message }
  end

  def bulk_tag
    @bulk_tag ||= @params["tag_id"].present? ? Tag.find(@params["tag_id"]) : Tag.find_or_create_named!(@params.fetch("tag_name"))
  end

  def enroll(person)
    sequence = Sequence.find(@params.fetch("sequence_id"))
    mailbox = Mailbox.find(@params.fetch("mailbox_id"))
    enrollment = SequenceRunner.enroll!(sequence: sequence, person: person, mailbox: mailbox)
    { "person_id" => person.id, "ok" => true, "enrollment_id" => enrollment.id }
  end

  def add_to_project(person)
    project = Project.find(@params.fetch("project_id"))
    member = ProjectMember.find_by(project_id: project.id, person_id: person.id)
    unless member
      pipeline = project.pipeline
      member = ProjectMember.create!(
        project: project,
        person: person,
        pipeline: pipeline,
        pipeline_version: pipeline&.version,
        current_stage_key: pipeline&.first_stage_key,
        status: "active",
        version: 1
      )
    end
    { "person_id" => person.id, "ok" => true, "project_member_id" => member.id }
  end
end
