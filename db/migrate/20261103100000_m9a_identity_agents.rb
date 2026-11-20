# frozen_string_literal: true

# M9a: real identity. Bearer credentials (personal, integration, agent, session,
# handoff), agents as first-class principals owned by a membership, and audit
# attribution for who acted on whose behalf, through which credential and surface.
class M9aIdentityAgents < ActiveRecord::Migration[8.1]
  # Permissions added to the system role presets in this milestone. Existing
  # organizations get them too, so turning on enforcement does not lock anyone out.
  PRESET_GRANTS = {
    "owner" => %w[
      job.read job.manage application.read application.create application.move_stage
      offer.read offer.create offer.send offer.rescind offer.approve offer.view_compensation
      interview.schedule scorecard.write scorecard.read_all project.read project.manage
      sequence.read sequence.manage sequence.enroll communication.send mailbox.read
      mailbox.connect mailbox.manage webhook.manage import.manage config.plan config.apply
      settings.manage compliance.manage agent.manage_own agent.manage integration.manage
    ],
    "admin" => %w[
      job.read job.manage application.read application.create application.move_stage
      offer.read offer.create offer.send offer.rescind offer.approve interview.schedule
      scorecard.write scorecard.read_all project.read project.manage sequence.read
      sequence.manage sequence.enroll communication.send mailbox.read mailbox.connect
      mailbox.manage webhook.manage import.manage config.plan settings.manage agent.manage_own
    ],
    "recruiter" => %w[
      job.read job.manage application.read application.create application.move_stage
      offer.read offer.create offer.send offer.approve interview.schedule scorecard.write
      project.read project.manage sequence.read sequence.manage sequence.enroll
      communication.send mailbox.read mailbox.connect agent.manage_own
    ],
    "hiring_manager" => %w[
      job.read application.read scorecard.write offer.read offer.approve agent.manage_own
    ]
  }.freeze

  def up
    create_table :agents, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :owner_membership_id, null: false, limit: 36
      t.string :name, null: false
      t.text :description
      t.string :status, null: false, default: "active" # active | paused | revoked
      t.json :scopes, null: false
      t.string :created_by_user_id, limit: 36
      t.integer :version, null: false, default: 1
      t.datetime :paused_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :agents, %i[organization_id id], unique: true, name: "index_agents_tenant_pk"
    add_index :agents, %i[organization_id owner_membership_id name], unique: true, name: "index_agents_owner_name"
    add_foreign_key :agents, :organizations, column: :organization_id
    execute <<~SQL.squish
      ALTER TABLE agents ADD CONSTRAINT fk_agents_memberships_tenant
        FOREIGN KEY (organization_id, owner_membership_id) REFERENCES memberships (organization_id, id)
    SQL

    create_table :api_credentials, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :kind, null: false # personal | integration | agent | session | handoff
      t.string :name, null: false
      t.string :token_prefix, null: false, limit: 16
      t.string :token_digest, null: false, limit: 64
      t.json :scopes, null: false
      t.string :user_id, limit: 36
      t.string :agent_id, limit: 36
      t.string :api_version, null: false, default: "2026-11-01"
      t.string :status, null: false, default: "active" # active | revoked | used
      t.datetime :expires_at
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.string :created_by_user_id, limit: 36
      t.integer :version, null: false, default: 1
      t.timestamps
    end
    add_index :api_credentials, :token_digest, unique: true
    add_index :api_credentials, %i[organization_id id], unique: true, name: "index_api_credentials_tenant_pk"
    add_index :api_credentials, %i[organization_id user_id], name: "index_api_credentials_user"
    add_index :api_credentials, %i[organization_id agent_id], name: "index_api_credentials_agent"
    add_foreign_key :api_credentials, :organizations, column: :organization_id
    add_foreign_key :api_credentials, :users, column: :user_id
    execute <<~SQL.squish
      ALTER TABLE api_credentials ADD CONSTRAINT fk_api_credentials_agents_tenant
        FOREIGN KEY (organization_id, agent_id) REFERENCES agents (organization_id, id)
    SQL

    add_column :audit_events, :on_behalf_of_id, :string, limit: 36
    add_column :audit_events, :credential_id, :string, limit: 36
    add_column :audit_events, :source_surface, :string, limit: 32

    grant_presets!
  end

  def down
    remove_column :audit_events, :source_surface
    remove_column :audit_events, :credential_id
    remove_column :audit_events, :on_behalf_of_id
    drop_table :api_credentials
    drop_table :agents
  end

  private

  def grant_presets!
    PRESET_GRANTS.each do |role_key, permissions|
      values = permissions.map { |p| "SELECT #{quote(p)} AS permission" }.join(" UNION ALL ")
      execute <<~SQL.squish
        INSERT IGNORE INTO role_permissions (id, organization_id, role_id, permission, created_at, updated_at)
        SELECT UUID(), r.organization_id, r.id, p.permission, NOW(6), NOW(6)
        FROM roles r CROSS JOIN (#{values}) p
        WHERE r.`system` = 1 AND r.`key` = #{quote(role_key)}
      SQL
    end
  end

  def quote(value)
    connection.quote(value)
  end
end
