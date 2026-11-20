# frozen_string_literal: true

class M10SourcingOps < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :do_not_contact_reason, :string
    add_column :people, :owner_user_id, :string, limit: 36
    add_index :people, %i[organization_id owner_user_id], name: "index_people_owner"
    add_index :people, %i[organization_id display_name], name: "index_people_display_name"

    add_column :sequences, :shared, :boolean, null: false, default: true
    add_column :sequences, :is_template, :boolean, null: false, default: false

    create_table :requisitions, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :code, null: false
      t.string :title, null: false
      t.string :employment_type
      t.integer :headcount, null: false, default: 1
      t.string :status, null: false, default: "draft"
      t.string :owner_user_id, limit: 36
      t.datetime :approved_at
      t.datetime :closed_at
      t.timestamps
    end
    add_index :requisitions, %i[organization_id id], unique: true, name: "index_requisitions_tenant_pk"
    add_index :requisitions, %i[organization_id code], unique: true
    add_index :requisitions, %i[organization_id status]
    add_foreign_key :requisitions, :organizations, column: :organization_id

    add_column :jobs, :requisition_id, :string, limit: 36
    add_index :jobs, %i[organization_id requisition_id]

    create_table :saved_searches, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :user_id, null: false, limit: 36
      t.string :name, null: false
      t.string :entity_type, null: false, default: "person"
      t.json :filters, null: false
      t.timestamps
    end
    add_index :saved_searches, %i[organization_id id], unique: true, name: "index_saved_searches_tenant_pk"
    add_index :saved_searches, %i[organization_id user_id]
    add_foreign_key :saved_searches, :organizations, column: :organization_id

    create_table :dnc_companies, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :company_id, limit: 36
      t.string :domain
      t.string :reason
      t.timestamps
    end
    add_index :dnc_companies, %i[organization_id id], unique: true, name: "index_dnc_companies_tenant_pk"
    add_index :dnc_companies, %i[organization_id company_id]
    add_index :dnc_companies, %i[organization_id domain]
    add_foreign_key :dnc_companies, :organizations, column: :organization_id

    create_table :referrals, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :referrer_user_id, null: false, limit: 36
      t.string :job_id, limit: 36
      t.string :application_id, limit: 36
      t.string :status, null: false, default: "submitted"
      t.string :note
      t.timestamps
    end
    add_index :referrals, %i[organization_id id], unique: true, name: "index_referrals_tenant_pk"
    add_index :referrals, %i[organization_id person_id]
    add_index :referrals, %i[organization_id referrer_user_id]
    add_index :referrals, %i[organization_id job_id]
    add_foreign_key :referrals, :organizations, column: :organization_id

    create_table :sourcing_tasks, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :sequence_enrollment_id, limit: 36
      t.string :assignee_user_id, limit: 36
      t.string :title, null: false
      t.string :status, null: false, default: "open"
      t.datetime :due_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :sourcing_tasks, %i[organization_id id], unique: true, name: "index_sourcing_tasks_tenant_pk"
    add_index :sourcing_tasks, %i[organization_id status]
    add_index :sourcing_tasks, %i[organization_id person_id]
    add_foreign_key :sourcing_tasks, :organizations, column: :organization_id
  end
end
