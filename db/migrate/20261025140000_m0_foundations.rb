# frozen_string_literal: true

class M0Foundations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end
    add_index :organizations, :slug, unique: true

    create_table :people, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :display_name, null: false
      t.integer :version, null: false, default: 1
      t.timestamps
    end
    add_index :people, %i[organization_id id], unique: true, name: "index_people_tenant_pk"
    add_foreign_key :people, :organizations, column: :organization_id

    create_table :audit_events, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :action, null: false
      t.string :resource_type, null: false
      t.string :resource_id, null: false, limit: 36
      t.string :actor_id, limit: 36
      t.string :actor_type
      t.json :change_set
      t.string :request_id
      t.timestamps
    end
    add_index :audit_events, %i[organization_id id], unique: true, name: "index_audit_events_tenant_pk"
    add_index :audit_events, %i[organization_id created_at]
    add_foreign_key :audit_events, :organizations, column: :organization_id

    create_table :outbox_events, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :event_type, null: false
      t.string :resource_type, null: false
      t.string :resource_id, null: false, limit: 36
      t.json :payload, null: false
      t.integer :subject_version
      t.datetime :delivered_at
      t.timestamps
    end
    add_index :outbox_events, %i[organization_id id], unique: true, name: "index_outbox_events_tenant_pk"
    add_index :outbox_events, %i[delivered_at created_at]
    add_foreign_key :outbox_events, :organizations, column: :organization_id

    create_table :idempotency_keys, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :request_path, null: false
      t.string :request_method, null: false
      t.integer :response_status, null: false
      t.json :response_body, null: false
      t.timestamps
    end
    add_index :idempotency_keys, %i[organization_id key], unique: true
    add_foreign_key :idempotency_keys, :organizations, column: :organization_id
  end
end
