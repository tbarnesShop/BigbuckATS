# frozen_string_literal: true

class M7bRetentionErasure < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :do_not_contact, :boolean, null: false, default: false

    create_table :legal_holds, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :subject_type, null: false # person | application | job
      t.string :subject_id, null: false, limit: 36
      t.string :reason, null: false
      t.string :placed_by_user_id, null: false, limit: 36
      t.datetime :placed_at, null: false
      t.string :released_by_user_id, limit: 36
      t.datetime :released_at
      t.timestamps
    end
    add_index :legal_holds, %i[organization_id subject_type subject_id], name: "index_legal_holds_subject"
    add_index :legal_holds, %i[organization_id id], unique: true, name: "index_legal_holds_tenant_pk"
    add_foreign_key :legal_holds, :organizations, column: :organization_id

    create_table :data_requests, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :person_id, limit: 36
      t.string :kind, null: false # access | correction | erasure
      t.string :requester_email
      t.datetime :received_at, null: false
      t.datetime :due_at, null: false
      t.string :status, null: false, default: "open" # open | completed | rejected
      t.datetime :completed_at
      t.string :assigned_user_id, limit: 36
      t.string :compliance_policy_id, limit: 36
      t.text :outcome_note
      t.timestamps
    end
    add_index :data_requests, %i[organization_id status due_at], name: "index_data_requests_open"
    add_index :data_requests, %i[organization_id id], unique: true, name: "index_data_requests_tenant_pk"
    add_foreign_key :data_requests, :organizations, column: :organization_id

    create_table :retention_actions, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :action, null: false # extension_requested | extended | review_queued | review_kept | anonymized | deleted | erased | held
      t.string :compliance_policy_id, limit: 36
      t.string :actor_id, limit: 36
      t.json :details
      t.datetime :created_at, null: false
    end
    add_index :retention_actions, %i[organization_id person_id created_at], name: "index_retention_actions_person"
    add_index :retention_actions, %i[organization_id id], unique: true, name: "index_retention_actions_tenant_pk"
    add_foreign_key :retention_actions, :organizations, column: :organization_id
  end
end
