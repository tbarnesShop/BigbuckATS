# frozen_string_literal: true

class M7aComplianceConsent < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :country, :string
    add_column :people, :region, :string

    create_table :compliance_policies, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :name, null: false
      t.integer :priority, null: false, default: 0
      t.boolean :is_fallback, null: false, default: false
      t.json :conditions # structured when / dimension-style
      t.json :requirements, null: false # notices, consents, blocks, retention, dataRequests
      t.timestamps
    end
    add_index :compliance_policies, %i[organization_id key], unique: true
    add_index :compliance_policies, %i[organization_id id], unique: true, name: "index_compliance_policies_tenant_pk"
    add_foreign_key :compliance_policies, :organizations, column: :organization_id

    create_table :notices, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :name, null: false
      t.string :renotify, null: false, default: "on-next-contact"
      t.timestamps
    end
    add_index :notices, %i[organization_id key], unique: true
    add_index :notices, %i[organization_id id], unique: true, name: "index_notices_tenant_pk"
    add_foreign_key :notices, :organizations, column: :organization_id

    create_table :notice_versions, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :notice_id, null: false, limit: 36
      t.integer :version_number, null: false
      t.string :locale, null: false
      t.text :body, null: false
      t.string :body_sha256, null: false
      t.datetime :created_at, null: false
    end
    add_index :notice_versions, %i[organization_id notice_id version_number locale], unique: true, name: "index_notice_versions_unique"
    add_index :notice_versions, %i[organization_id id], unique: true, name: "index_notice_versions_tenant_pk"
    add_foreign_key :notice_versions, :organizations, column: :organization_id

    create_table :consent_purposes, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :label, null: false
      t.string :lawful_basis, null: false
      t.text :description
      t.timestamps
    end
    add_index :consent_purposes, %i[organization_id key], unique: true
    add_index :consent_purposes, %i[organization_id id], unique: true, name: "index_consent_purposes_tenant_pk"
    add_foreign_key :consent_purposes, :organizations, column: :organization_id

    create_table :consents, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :consent_purpose_id, null: false, limit: 36
      t.string :notice_version_id, limit: 36
      t.string :compliance_policy_id, limit: 36
      t.string :lawful_basis, null: false
      t.string :status, null: false # granted | withdrawn | expired
      t.string :captured_via, null: false
      t.datetime :captured_at, null: false
      t.datetime :expires_at
      t.string :ip_address
      t.string :user_agent
      t.json :evidence_json
      t.datetime :created_at, null: false
    end
    add_index :consents, %i[organization_id person_id consent_purpose_id captured_at], name: "index_consents_current"
    add_index :consents, %i[organization_id id], unique: true, name: "index_consents_tenant_pk"
    add_foreign_key :consents, :organizations, column: :organization_id

    create_table :notice_receipts, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :notice_version_id, null: false, limit: 36
      t.string :shown_via, null: false # apply_form | first_outreach
      t.string :locale, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :shown_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :notice_receipts, %i[organization_id person_id notice_version_id], name: "index_notice_receipts_person"
    add_index :notice_receipts, %i[organization_id id], unique: true, name: "index_notice_receipts_tenant_pk"
    add_foreign_key :notice_receipts, :organizations, column: :organization_id
  end
end
