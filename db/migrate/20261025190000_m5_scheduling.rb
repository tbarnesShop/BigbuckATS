# frozen_string_literal: true

class M5Scheduling < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_connections, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :kind, null: false # user | domain
      t.string :user_id, limit: 36
      t.string :calendar_id, null: false
      t.string :secret_ref, null: false
      t.string :status, null: false, default: "connected"
      t.timestamps
    end
    add_index :calendar_connections, %i[organization_id id], unique: true, name: "index_calendar_connections_tenant_pk"
    add_foreign_key :calendar_connections, :organizations, column: :organization_id

    create_table :interviewer_profiles, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :user_id, null: false, limit: 36
      t.string :time_zone, null: false, default: "UTC"
      t.json :working_hours, null: false # {"mon":[["09:00","17:00"]],...}
      t.integer :daily_limit, null: false, default: 4
      t.integer :weekly_limit, null: false, default: 15
      t.integer :buffer_minutes, null: false, default: 15
      t.boolean :paused, null: false, default: false
      t.timestamps
    end
    add_index :interviewer_profiles, %i[organization_id user_id], unique: true
    add_index :interviewer_profiles, %i[organization_id id], unique: true, name: "index_interviewer_profiles_tenant_pk"
    add_foreign_key :interviewer_profiles, :organizations, column: :organization_id

    create_table :interviewer_pools, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :interviewer_pools, %i[organization_id key], unique: true
    add_index :interviewer_pools, %i[organization_id id], unique: true, name: "index_interviewer_pools_tenant_pk"
    add_foreign_key :interviewer_pools, :organizations, column: :organization_id

    create_table :interviewer_pool_members, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :interviewer_pool_id, null: false, limit: 36
      t.string :user_id, null: false, limit: 36
      t.boolean :trainee, null: false, default: false
      t.boolean :paused, null: false, default: false
      t.timestamps
    end
    add_index :interviewer_pool_members, %i[organization_id interviewer_pool_id user_id], unique: true, name: "index_pool_members_unique"
    add_index :interviewer_pool_members, %i[organization_id id], unique: true, name: "index_pool_members_tenant_pk"
    add_foreign_key :interviewer_pool_members, :organizations, column: :organization_id

    create_table :interviews, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :application_id, null: false, limit: 36
      t.string :stage_key, null: false
      t.string :interview_key, null: false
      t.string :status, null: false, default: "requested" # requested | scheduled | completed | cancelled | needs_attention
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :calendar_event_id
      t.json :interviewer_user_ids
      t.string :on_decline, null: false, default: "replace_from_pool"
      t.timestamps
    end
    add_index :interviews, %i[organization_id application_id stage_key interview_key], name: "index_interviews_application"
    add_index :interviews, %i[organization_id id], unique: true, name: "index_interviews_tenant_pk"
    add_foreign_key :interviews, :organizations, column: :organization_id
    add_foreign_key :interviews, :applications, column: %i[organization_id application_id], primary_key: %i[organization_id id], name: "fk_interviews_applications_tenant"

    create_table :scorecards, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :interview_id, null: false, limit: 36
      t.string :user_id, null: false, limit: 36
      t.string :status, null: false, default: "draft" # draft | submitted
      t.string :rating
      t.text :notes
      t.timestamps
    end
    add_index :scorecards, %i[organization_id interview_id user_id], unique: true
    add_index :scorecards, %i[organization_id id], unique: true, name: "index_scorecards_tenant_pk"
    add_foreign_key :scorecards, :organizations, column: :organization_id
  end
end
