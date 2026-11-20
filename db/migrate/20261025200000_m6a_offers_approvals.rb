# frozen_string_literal: true

class M6aOffersApprovals < ActiveRecord::Migration[8.1]
  def change
    add_column :dimension_values, :attributes_json, :json
    add_column :custom_fields, :requires_reapproval, :boolean, null: false, default: false

    create_table :hiring_teams, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :job_id, null: false, limit: 36
      t.timestamps
    end
    add_index :hiring_teams, %i[organization_id job_id], unique: true
    add_index :hiring_teams, %i[organization_id id], unique: true, name: "index_hiring_teams_tenant_pk"
    add_foreign_key :hiring_teams, :organizations, column: :organization_id

    create_table :hiring_team_members, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :hiring_team_id, null: false, limit: 36
      t.string :user_id, null: false, limit: 36
      t.string :team_role, null: false # hiring-manager | recruiter | interviewer | ...
      t.timestamps
    end
    add_index :hiring_team_members, %i[organization_id hiring_team_id user_id team_role], unique: true, name: "index_hiring_team_members_unique"
    add_index :hiring_team_members, %i[organization_id id], unique: true, name: "index_hiring_team_members_tenant_pk"
    add_foreign_key :hiring_team_members, :organizations, column: :organization_id

    create_table :approval_policies, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :name, null: false
      t.string :applies_to, null: false # offer | requisition
      t.integer :priority, null: false, default: 0
      t.boolean :is_catch_all, null: false, default: false
      t.json :conditions # structured when rule or dimension-style hash
      t.json :reapproval_fields
      t.timestamps
    end
    add_index :approval_policies, %i[organization_id key], unique: true
    add_index :approval_policies, %i[organization_id applies_to priority], name: "index_approval_policies_match"
    add_index :approval_policies, %i[organization_id id], unique: true, name: "index_approval_policies_tenant_pk"
    add_foreign_key :approval_policies, :organizations, column: :organization_id

    create_table :approval_policy_steps, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :approval_policy_id, null: false, limit: 36
      t.integer :position, null: false
      t.string :name, null: false
      t.string :mode, null: false, default: "sequential" # sequential | parallel
      t.json :approvers, null: false # ["role:hiring-manager", "attribute:job.dimensions.department.head"]
      t.string :require_mode, null: false, default: "all" # all | any | number as string
      t.json :step_when
      t.string :if_no_approver, null: false, default: "skip" # skip | fallback | block
      t.string :fallback_approver
      t.boolean :allow_self_approval, null: false, default: false
      t.timestamps
    end
    add_index :approval_policy_steps, %i[organization_id approval_policy_id position], unique: true, name: "index_approval_policy_steps_position"
    add_index :approval_policy_steps, %i[organization_id id], unique: true, name: "index_approval_policy_steps_tenant_pk"
    add_foreign_key :approval_policy_steps, :organizations, column: :organization_id

    create_table :offers, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :application_id, null: false, limit: 36
      t.string :status, null: false, default: "draft"
      t.string :current_version_id, limit: 36
      t.string :rescind_reason_key
      t.string :live_key, limit: 36 # application_id while live; null when rescinded
      t.integer :version, null: false, default: 1
      t.timestamps
    end
    add_index :offers, %i[organization_id live_key], unique: true, name: "index_offers_one_live"
    add_index :offers, %i[organization_id application_id]
    add_index :offers, %i[organization_id id], unique: true, name: "index_offers_tenant_pk"
    add_foreign_key :offers, :organizations, column: :organization_id
    add_foreign_key :offers, :applications, column: %i[organization_id application_id], primary_key: %i[organization_id id], name: "fk_offers_applications_tenant"

    create_table :offer_versions, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :offer_id, null: false, limit: 36
      t.integer :version_number, null: false
      t.json :fields, null: false
      t.string :approval_policy_id, limit: 36
      t.string :approval_state, null: false, default: "not_required"
      t.string :supersedes_version_id, limit: 36
      t.string :created_by_type, null: false, default: "User"
      t.string :created_by_id, limit: 36
      t.datetime :sent_at
      t.datetime :expires_at
      t.timestamps
    end
    add_index :offer_versions, %i[organization_id offer_id version_number], unique: true, name: "index_offer_versions_number"
    add_index :offer_versions, %i[organization_id id], unique: true, name: "index_offer_versions_tenant_pk"
    add_foreign_key :offer_versions, :organizations, column: :organization_id

    create_table :approvals, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :entity_type, null: false
      t.string :entity_id, null: false, limit: 36
      t.string :entity_version_id, limit: 36
      t.string :approval_policy_id, limit: 36
      t.string :approval_policy_step_id, limit: 36
      t.string :step_key
      t.integer :step_position
      t.string :approver_user_id, limit: 36
      t.string :resolved_from
      t.string :requested_by_user_id, limit: 36
      t.datetime :requested_at
      t.string :approved_by_user_id, limit: 36
      t.datetime :approved_at
      t.string :status, null: false, default: "pending" # pending | approved | changes_requested | skipped | cancelled
      t.boolean :is_override, null: false, default: false
      t.string :reason
      t.json :metadata_json
      t.timestamps
    end
    add_index :approvals, %i[organization_id entity_type entity_id], name: "index_approvals_entity"
    add_index :approvals, %i[organization_id approver_user_id status], name: "index_approvals_approver"
    add_index :approvals, %i[organization_id id], unique: true, name: "index_approvals_tenant_pk"
    add_foreign_key :approvals, :organizations, column: :organization_id
  end
end
