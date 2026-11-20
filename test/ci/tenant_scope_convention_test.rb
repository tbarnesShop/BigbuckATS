# frozen_string_literal: true

require "test_helper"

class TenantScopeConventionTest < ActiveSupport::TestCase
  TENANT_TABLES = %w[
    people audit_events outbox_events idempotency_keys
    roles role_permissions memberships person_contact_points companies
    person_affiliations merge_suggestions dimensions dimension_values
    entity_dimension_values membership_scopes custom_fields custom_field_values documents
    pipeline_templates pipeline_template_versions pipelines jobs applications
    projects project_members stage_transitions postings
    config_objects config_revisions config_plans
    mailboxes message_templates sequences sequence_enrollments
    communications scheduled_messages timeline_events sandbox_messages opt_outs person_notes tags person_tags outreach_snapshots rediscovery_candidates agent_proposals
    calendar_connections interviewer_profiles interviewer_pools interviewer_pool_members
    interviews scorecards holidays rooms interviewer_blocks
    scheduling_links availability_requests calendar_watch_channels
    hiring_teams hiring_team_members approval_policies approval_policy_steps
    offers offer_versions approvals
    offer_templates offer_documents signature_requests offer_responses
    compliance_policies notices notice_versions consent_purposes consents notice_receipts
    legal_holds data_requests retention_actions
    import_runs import_rows webhook_endpoints webhook_deliveries
    verified_domains break_glass_sessions
    agents api_credentials oauth_identities custom_field_versions application_question_templates
  ].freeze


  test "tenant tables are covered by TenantScoped models" do
    Rails.application.eager_load!
    scoped = ApplicationRecord.descendants.select { |m| m.included_modules.include?(TenantScoped) }
    covered = scoped.map(&:table_name)
    missing = TENANT_TABLES - covered
    assert_empty missing, "tenant tables missing TenantScoped: #{missing.join(', ')}"
  end

  test "TenantScoped models declare organization_id" do
    Rails.application.eager_load!
    scoped = ApplicationRecord.descendants.select { |m| m.included_modules.include?(TenantScoped) }
    scoped.each do |model|
      assert_includes model.column_names, "organization_id", "#{model.name} missing organization_id"
    end
  end
end
