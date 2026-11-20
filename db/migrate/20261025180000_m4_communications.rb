# frozen_string_literal: true

class M4Communications < ActiveRecord::Migration[8.1]
  def change
    create_table :mailboxes, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :kind, null: false # personal | shared
      t.string :email, null: false
      t.string :user_id, limit: 36 # personal owner
      t.string :status, null: false, default: "connected"
      t.integer :daily_send_count, null: false, default: 0
      t.date :daily_send_on
      t.integer :daily_cap, null: false, default: 2000
      t.string :secret_ref # Secret Manager pointer; never store tokens in DB
      t.timestamps
    end
    add_index :mailboxes, %i[organization_id email], unique: true
    add_index :mailboxes, %i[organization_id id], unique: true, name: "index_mailboxes_tenant_pk"
    add_foreign_key :mailboxes, :organizations, column: :organization_id

    create_table :message_templates, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :message_type, null: false
      t.string :locale, null: false, default: "en"
      t.string :subject, null: false
      t.text :body, null: false
      t.timestamps
    end
    add_index :message_templates, %i[organization_id key locale], unique: true
    add_index :message_templates, %i[organization_id id], unique: true, name: "index_message_templates_tenant_pk"
    add_foreign_key :message_templates, :organizations, column: :organization_id

    create_table :sequences, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :name, null: false
      t.json :steps, null: false # [{type: email|wait|task, template_key?, wait_days?}]
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :sequences, %i[organization_id key], unique: true
    add_index :sequences, %i[organization_id id], unique: true, name: "index_sequences_tenant_pk"
    add_foreign_key :sequences, :organizations, column: :organization_id

    create_table :sequence_enrollments, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :sequence_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :mailbox_id, null: false, limit: 36
      t.integer :step_index, null: false, default: 0
      t.string :status, null: false, default: "active" # active | stopped | completed | paused
      t.string :stop_reason
      t.timestamps
    end
    add_index :sequence_enrollments, %i[organization_id sequence_id person_id], unique: true, name: "index_enrollments_unique"
    add_index :sequence_enrollments, %i[organization_id id], unique: true, name: "index_enrollments_tenant_pk"
    add_foreign_key :sequence_enrollments, :organizations, column: :organization_id

    create_table :communications, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :mailbox_id, limit: 36
      t.string :direction, null: false # outbound | inbound
      t.string :channel, null: false, default: "email"
      t.string :subject
      t.text :body
      t.string :provider_message_id
      t.string :thread_id
      t.string :sequence_enrollment_id, limit: 36
      t.string :message_type
      t.string :status, null: false, default: "sent"
      t.timestamps
    end
    add_index :communications, %i[organization_id person_id created_at], name: "index_communications_person"
    add_index :communications, %i[organization_id id], unique: true, name: "index_communications_tenant_pk"
    add_index :communications, %i[organization_id provider_message_id], unique: true, name: "index_communications_provider_msg"
    add_foreign_key :communications, :organizations, column: :organization_id
    add_foreign_key :communications, :people, column: %i[organization_id person_id], primary_key: %i[organization_id id], name: "fk_communications_people_tenant"

    create_table :scheduled_messages, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :mailbox_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :sequence_enrollment_id, limit: 36
      t.string :template_key
      t.string :subject, null: false
      t.text :body, null: false
      t.string :status, null: false, default: "queued" # queued | sent | cancelled | failed
      t.datetime :send_at, null: false
      t.integer :attempts, null: false, default: 0
      t.timestamps
    end
    add_index :scheduled_messages, %i[organization_id status send_at], name: "index_scheduled_messages_queue"
    add_index :scheduled_messages, %i[organization_id id], unique: true, name: "index_scheduled_messages_tenant_pk"
    add_foreign_key :scheduled_messages, :organizations, column: :organization_id

    create_table :timeline_events, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :event_type, null: false
      t.string :outbox_event_id, limit: 36
      t.json :payload, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :timeline_events, %i[organization_id person_id occurred_at], name: "index_timeline_events_person"
    add_index :timeline_events, %i[organization_id id], unique: true, name: "index_timeline_events_tenant_pk"
    add_index :timeline_events, %i[organization_id outbox_event_id], unique: true, name: "index_timeline_events_outbox"
    add_foreign_key :timeline_events, :organizations, column: :organization_id
  end
end
