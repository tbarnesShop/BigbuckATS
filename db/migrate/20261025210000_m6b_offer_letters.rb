# frozen_string_literal: true

class M6bOfferLetters < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :settings, :json

    create_table :offer_templates, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :name, null: false
      t.string :format, null: false, default: "html" # html | markdown
      t.text :body, null: false
      t.json :available_for # { "department" => ["engineering"], ... }
      t.integer :expires_after_days, null: false, default: 7
      t.timestamps
    end
    add_index :offer_templates, %i[organization_id key], unique: true
    add_index :offer_templates, %i[organization_id id], unique: true, name: "index_offer_templates_tenant_pk"
    add_foreign_key :offer_templates, :organizations, column: :organization_id

    create_table :offer_documents, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :offer_version_id, null: false, limit: 36
      t.string :kind, null: false # letter | attachment | acceptance_record
      t.text :body_html
      t.string :sha256
      t.timestamps
    end
    add_index :offer_documents, %i[organization_id offer_version_id kind], name: "index_offer_documents_version"
    add_index :offer_documents, %i[organization_id id], unique: true, name: "index_offer_documents_tenant_pk"
    add_foreign_key :offer_documents, :organizations, column: :organization_id

    create_table :signature_requests, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :offer_version_id, null: false, limit: 36
      t.string :provider, null: false, default: "click_to_accept"
      t.string :sent_to_email, null: false
      t.string :status, null: false, default: "sent" # sent | viewed | completed | declined | voided | expired
      t.datetime :expires_at, null: false
      t.datetime :viewed_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :signature_requests, %i[organization_id offer_version_id]
    add_index :signature_requests, %i[organization_id id], unique: true, name: "index_signature_requests_tenant_pk"
    add_foreign_key :signature_requests, :organizations, column: :organization_id

    create_table :offer_responses, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :offer_version_id, null: false, limit: 36
      t.string :response, null: false # accepted | declined
      t.string :responded_by, null: false # candidate | recorded_by_user
      t.string :recorded_by_user_id, limit: 36
      t.string :reason_key
      t.text :note
      t.string :document_sha256
      t.string :ip_address
      t.string :user_agent
      t.string :link_sent_to_email
      t.string :typed_name
      t.datetime :created_at, null: false
    end
    add_index :offer_responses, %i[organization_id offer_version_id], unique: true
    add_index :offer_responses, %i[organization_id id], unique: true, name: "index_offer_responses_tenant_pk"
    add_foreign_key :offer_responses, :organizations, column: :organization_id

    add_column :offer_versions, :offer_template_id, :string, limit: 36
  end
end
