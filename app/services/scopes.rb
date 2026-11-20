# frozen_string_literal: true

# API scopes and the permissions each grants (ported from BigBuck-ATS
# packages/domain/src/identity/principal.ts, renamed to this app's vocabulary).
# Personal and agent credentials get scopes ∩ the owning user's role; integration
# credentials get exactly their scopes, org-wide.
module Scopes
  MAP = {
    "people:read" => %w[person.read],
    "people:read_restricted" => %w[person.read person.read_restricted],
    "people:write" => %w[person.read person.create person.update person.edit_details],
    "people:merge" => %w[person.read person.merge],
    "people:export" => %w[person.read person.export],
    "people:erase" => %w[person.read person.erase],
    "companies:write" => %w[company.manage],
    "documents:read" => %w[document.read],
    "documents:write" => %w[document.read document.upload],
    "jobs:read" => %w[job.read application.read],
    "jobs:write" => %w[job.read job.manage application.read],
    "confidential:read" => %w[job.read_confidential project.read_confidential],
    "applications:write" => %w[application.read application.create person.read person.create],
    "applications:transition" => %w[application.read application.move_stage],
    "projects:read" => %w[project.read person.read],
    "projects:write" => %w[project.read project.manage person.read person.create],
    "sequences:read" => %w[sequence.read person.read],
    "sequences:write" => %w[sequence.read sequence.manage sequence.enroll person.read],
    "sequences:enroll" => %w[sequence.read sequence.enroll person.read],
    "communications:send" => %w[communication.send person.read],
    "mailboxes:read" => %w[mailbox.read],
    "mailboxes:write" => %w[mailbox.read mailbox.connect mailbox.manage],
    "scheduling:write" => %w[application.read interview.schedule],
    "scorecards:write" => %w[application.read scorecard.write],
    "scorecards:read" => %w[application.read scorecard.read_all],
    "scorecards:manage" => %w[application.read scorecard.read_all scorecard.manage],
    "offers:read" => %w[application.read offer.read],
    "offers:write" => %w[application.read offer.read offer.create offer.send offer.rescind],
    "offers:approve" => %w[offer.read offer.approve],
    "offers:compensation" => %w[offer.view_compensation],
    "webhooks:write" => %w[webhook.manage],
    "events:read" => %w[audit.read],
    "imports:write" => %w[import.manage person.read person.create],
    "config:plan" => %w[config.plan],
    "config:apply" => %w[config.plan config.apply],
    "settings:write" => %w[settings.manage],
    "compliance:write" => %w[compliance.manage],
    "structure:write" => %w[dimension.manage custom_field.manage],
    "roles:write" => %w[role.manage],
    "agents:write" => %w[agent.manage_own],
    "analytics:read" => %w[analytics.read],
    "credentials:manage" => %w[integration.manage]
  }.freeze

  ALL = MAP.keys.freeze

  # Scopes whose every permission the role holds: what a member could grant an agent themselves.
  def self.grantable_for(permissions)
    held = Array(permissions).to_set
    MAP.select { |_scope, needs| needs.all? { |permission| held.include?(permission) } }.keys
  end

  module_function

  def unknown(scopes)
    Array(scopes).map(&:to_s) - ALL
  end

  def permissions_for(scopes)
    Array(scopes).flat_map { |s| MAP.fetch(s.to_s, []) }.to_set
  end
end
