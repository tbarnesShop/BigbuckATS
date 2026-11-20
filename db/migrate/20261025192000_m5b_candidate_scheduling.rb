# frozen_string_literal: true

class M5bCandidateScheduling < ActiveRecord::Migration[8.1]
  def change
    create_table :scheduling_links, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :application_id, null: false, limit: 36
      t.string :kind, null: false # self_schedule | availability | reschedule
      t.json :interview_keys, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :scheduling_links, %i[organization_id id], unique: true, name: "index_scheduling_links_tenant_pk"
    add_index :scheduling_links, %i[organization_id application_id]
    add_foreign_key :scheduling_links, :organizations, column: :organization_id
    add_foreign_key :scheduling_links, :applications, column: %i[organization_id application_id], primary_key: %i[organization_id id], name: "fk_scheduling_links_applications_tenant"

    create_table :availability_requests, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :scheduling_link_id, null: false, limit: 36
      t.string :candidate_time_zone
      t.json :windows
      t.boolean :auto_book, null: false, default: false
      t.datetime :submitted_at
      t.timestamps
    end
    add_index :availability_requests, %i[organization_id scheduling_link_id], unique: true, name: "index_availability_requests_link"
    add_index :availability_requests, %i[organization_id id], unique: true, name: "index_availability_requests_tenant_pk"
    add_foreign_key :availability_requests, :organizations, column: :organization_id

    create_table :calendar_watch_channels, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :calendar_connection_id, null: false, limit: 36
      t.string :calendar_id, null: false
      t.string :channel_id, null: false
      t.string :resource_id
      t.datetime :expires_at, null: false
      t.string :sync_token
      t.datetime :last_synced_at
      t.timestamps
    end
    add_index :calendar_watch_channels, %i[organization_id channel_id], unique: true
    add_index :calendar_watch_channels, %i[organization_id id], unique: true, name: "index_calendar_watch_channels_tenant_pk"
    add_foreign_key :calendar_watch_channels, :organizations, column: :organization_id

    add_column :interviews, :interviewer_pool_id, :string, limit: 36
    add_column :interviews, :needs_attention_reason, :string
  end
end
