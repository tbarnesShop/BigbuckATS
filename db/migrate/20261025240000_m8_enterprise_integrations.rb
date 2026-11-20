# frozen_string_literal: true

class M8EnterpriseIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :import_runs, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :source, null: false, default: "csv"
      t.string :entity, null: false # people | jobs | applications
      t.string :status, null: false, default: "pending" # pending | dry_run | applied | failed
      t.json :field_mapping, null: false
      t.integer :row_count, null: false, default: 0
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.json :errors_json
      t.string :actor_id, limit: 36
      t.timestamps
    end
    add_index :import_runs, %i[organization_id id], unique: true, name: "index_import_runs_tenant_pk"
    add_foreign_key :import_runs, :organizations, column: :organization_id

    create_table :import_rows, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :import_run_id, null: false, limit: 36
      t.integer :row_number, null: false
      t.string :source_id
      t.string :resource_type
      t.string :resource_id, limit: 36
      t.json :raw
      t.json :mapped
      t.string :status, null: false, default: "pending" # pending | created | updated | skipped | error
      t.string :error_message
      t.timestamps
    end
    add_index :import_rows, %i[organization_id import_run_id row_number], unique: true, name: "index_import_rows_number"
    add_index :import_rows, %i[organization_id id], unique: true, name: "index_import_rows_tenant_pk"
    add_foreign_key :import_rows, :organizations, column: :organization_id

    create_table :webhook_endpoints, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :url, null: false
      t.string :secret_ref, null: false
      t.json :event_types # null = all
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :webhook_endpoints, %i[organization_id key], unique: true
    add_index :webhook_endpoints, %i[organization_id id], unique: true, name: "index_webhook_endpoints_tenant_pk"
    add_foreign_key :webhook_endpoints, :organizations, column: :organization_id

    create_table :webhook_deliveries, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :webhook_endpoint_id, null: false, limit: 36
      t.string :outbox_event_id, null: false, limit: 36
      t.string :event_type, null: false
      t.string :status, null: false, default: "pending" # pending | delivered | failed
      t.integer :attempt_count, null: false, default: 0
      t.integer :response_status
      t.string :response_snippet
      t.datetime :delivered_at
      t.timestamps
    end
    add_index :webhook_deliveries, %i[organization_id webhook_endpoint_id status], name: "index_webhook_deliveries_status"
    add_index :webhook_deliveries, %i[organization_id id], unique: true, name: "index_webhook_deliveries_tenant_pk"
    add_foreign_key :webhook_deliveries, :organizations, column: :organization_id

    create_table :verified_domains, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :domain, null: false
      t.string :status, null: false, default: "pending" # pending | verified
      t.datetime :verified_at
      t.timestamps
    end
    add_index :verified_domains, %i[organization_id domain], unique: true
    add_index :verified_domains, %i[organization_id id], unique: true, name: "index_verified_domains_tenant_pk"
    add_foreign_key :verified_domains, :organizations, column: :organization_id

    create_table :break_glass_sessions, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :opened_by_user_id, null: false, limit: 36
      t.string :reason, null: false
      t.json :kinds
      t.datetime :opens_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :closed_at
      t.datetime :reconciled_at
      t.string :status, null: false, default: "open" # open | closed | reconciled
      t.timestamps
    end
    add_index :break_glass_sessions, %i[organization_id status], name: "index_break_glass_sessions_status"
    add_index :break_glass_sessions, %i[organization_id id], unique: true, name: "index_break_glass_sessions_tenant_pk"
    add_foreign_key :break_glass_sessions, :organizations, column: :organization_id

    add_column :organizations, :repository_lock, :boolean, null: false, default: false
    add_column :people, :source_system, :string
    add_column :people, :source_id, :string
    add_index :people, %i[organization_id source_system source_id], name: "index_people_source"
  end
end
