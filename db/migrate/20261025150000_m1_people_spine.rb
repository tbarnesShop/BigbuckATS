# frozen_string_literal: true

class M1PeopleSpine < ActiveRecord::Migration[8.1]
  def change
    # --- Identity ---
    create_table :users, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :roles, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :name, null: false
      t.boolean :system, null: false, default: false
      t.timestamps
    end
    add_index :roles, %i[organization_id key], unique: true
    add_index :roles, %i[organization_id id], unique: true, name: "index_roles_tenant_pk"
    add_foreign_key :roles, :organizations, column: :organization_id

    create_table :role_permissions, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :role_id, null: false, limit: 36
      t.string :permission, null: false
      t.timestamps
    end
    add_index :role_permissions, %i[organization_id role_id permission], unique: true, name: "index_role_permissions_unique"
    add_index :role_permissions, %i[organization_id id], unique: true, name: "index_role_permissions_tenant_pk"
    add_foreign_key :role_permissions, :organizations, column: :organization_id
    add_foreign_key :role_permissions, :roles, column: :role_id

    create_table :memberships, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :user_id, null: false, limit: 36
      t.string :role_id, null: false, limit: 36
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :memberships, %i[organization_id user_id], unique: true
    add_index :memberships, %i[organization_id id], unique: true, name: "index_memberships_tenant_pk"
    add_foreign_key :memberships, :organizations, column: :organization_id
    add_foreign_key :memberships, :users, column: :user_id
    add_foreign_key :memberships, :roles, column: :role_id

    # --- People spine ---
    change_table :people, bulk: true do |t|
      t.string :lifecycle_stage, null: false, default: "prospect"
      t.string :visibility, null: false, default: "public"
      t.string :primary_email
      t.string :primary_phone
      t.string :merged_into_id, limit: 36
      t.datetime :erased_at
    end
    add_index :people, %i[organization_id lifecycle_stage]
    add_index :people, %i[organization_id primary_email]

    create_table :person_contact_points, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :kind, null: false # email, phone, url
      t.string :value, null: false
      t.string :normalized_value, null: false
      t.boolean :verified, null: false, default: false
      t.boolean :primary, null: false, default: false
      t.string :duplicate_of_person_id, limit: 36
      # Set to normalized_value for canonical rows; NULL for held duplicates (MySQL allows many NULLs in a UNIQUE).
      t.string :canonical_key
      t.timestamps
    end
    add_index :person_contact_points, %i[organization_id kind canonical_key],
              unique: true, name: "index_contact_points_unique_value"
    add_index :person_contact_points, %i[organization_id id], unique: true, name: "index_contact_points_tenant_pk"
    add_index :person_contact_points, %i[organization_id person_id]
    add_foreign_key :person_contact_points, :organizations, column: :organization_id
    add_foreign_key :person_contact_points, :people,
                    column: %i[organization_id person_id], primary_key: %i[organization_id id],
                    name: "fk_contact_points_people_tenant"

    create_table :companies, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :domain
      t.timestamps
    end
    add_index :companies, %i[organization_id normalized_name]
    add_index :companies, %i[organization_id id], unique: true, name: "index_companies_tenant_pk"
    add_foreign_key :companies, :organizations, column: :organization_id

    create_table :person_affiliations, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :company_id, null: false, limit: 36
      t.string :title
      t.boolean :current, null: false, default: false
      t.date :started_on
      t.date :ended_on
      t.timestamps
    end
    add_index :person_affiliations, %i[organization_id person_id company_id], name: "index_affiliations_person_company"
    add_index :person_affiliations, %i[organization_id id], unique: true, name: "index_affiliations_tenant_pk"
    add_foreign_key :person_affiliations, :organizations, column: :organization_id
    add_foreign_key :person_affiliations, :people,
                    column: %i[organization_id person_id], primary_key: %i[organization_id id],
                    name: "fk_affiliations_people_tenant"
    add_foreign_key :person_affiliations, :companies,
                    column: %i[organization_id company_id], primary_key: %i[organization_id id],
                    name: "fk_affiliations_companies_tenant"

    create_table :merge_suggestions, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :person_a_id, null: false, limit: 36
      t.string :person_b_id, null: false, limit: 36
      t.string :reason, null: false
      t.string :status, null: false, default: "open"
      t.timestamps
    end
    add_index :merge_suggestions, %i[organization_id person_a_id person_b_id], unique: true, name: "index_merge_suggestions_pair"
    add_index :merge_suggestions, %i[organization_id id], unique: true, name: "index_merge_suggestions_tenant_pk"
    add_foreign_key :merge_suggestions, :organizations, column: :organization_id

    # --- Dimensions & scopes ---
    create_table :dimensions, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :label, null: false
      t.boolean :hierarchical, null: false, default: false
      t.boolean :system, null: false, default: false
      t.json :applies_to, null: false
      t.timestamps
    end
    add_index :dimensions, %i[organization_id key], unique: true
    add_index :dimensions, %i[organization_id id], unique: true, name: "index_dimensions_tenant_pk"
    add_foreign_key :dimensions, :organizations, column: :organization_id

    create_table :dimension_values, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :dimension_id, null: false, limit: 36
      t.string :key, null: false
      t.string :label, null: false
      t.string :parent_id, limit: 36
      t.string :status, null: false, default: "active"
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :dimension_values, %i[organization_id dimension_id key], unique: true, name: "index_dimension_values_key"
    add_index :dimension_values, %i[organization_id id], unique: true, name: "index_dimension_values_tenant_pk"
    add_foreign_key :dimension_values, :organizations, column: :organization_id
    add_foreign_key :dimension_values, :dimensions, column: :dimension_id

    create_table :entity_dimension_values, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :entity_type, null: false
      t.string :entity_id, null: false, limit: 36
      t.string :dimension_id, null: false, limit: 36
      t.string :dimension_value_id, null: false, limit: 36
      t.timestamps
    end
    add_index :entity_dimension_values,
              %i[organization_id entity_type entity_id dimension_id dimension_value_id],
              unique: true, name: "index_entity_dimension_values_unique"
    add_index :entity_dimension_values, %i[organization_id id], unique: true, name: "index_entity_dim_values_tenant_pk"
    add_foreign_key :entity_dimension_values, :organizations, column: :organization_id

    create_table :membership_scopes, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :membership_id, null: false, limit: 36
      t.string :dimension_id, null: false, limit: 36
      t.string :dimension_value_id, null: false, limit: 36
      t.boolean :include_descendants, null: false, default: true
      t.timestamps
    end
    add_index :membership_scopes, %i[organization_id membership_id], name: "index_membership_scopes_membership"
    add_index :membership_scopes, %i[organization_id id], unique: true, name: "index_membership_scopes_tenant_pk"
    add_foreign_key :membership_scopes, :organizations, column: :organization_id
    add_foreign_key :membership_scopes, :memberships, column: :membership_id

    # --- Custom fields ---
    create_table :custom_fields, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :entity, null: false
      t.string :key, null: false
      t.string :label, null: false
      t.string :field_type, null: false
      t.string :data_class, null: false, default: "internal"
      t.json :visibility_roles
      t.timestamps
    end
    add_index :custom_fields, %i[organization_id entity key], unique: true
    add_index :custom_fields, %i[organization_id id], unique: true, name: "index_custom_fields_tenant_pk"
    add_foreign_key :custom_fields, :organizations, column: :organization_id

    create_table :custom_field_values, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :custom_field_id, null: false, limit: 36
      t.string :entity_type, null: false
      t.string :entity_id, null: false, limit: 36
      t.text :value_text
      t.decimal :value_number, precision: 18, scale: 4
      t.date :value_date
      t.json :value_json
      t.timestamps
    end
    add_index :custom_field_values, %i[organization_id custom_field_id entity_type entity_id],
              unique: true, name: "index_custom_field_values_unique"
    add_index :custom_field_values, %i[organization_id id], unique: true, name: "index_custom_field_values_tenant_pk"
    add_foreign_key :custom_field_values, :organizations, column: :organization_id
    add_foreign_key :custom_field_values, :custom_fields, column: :custom_field_id

    # --- Documents ---
    create_table :documents, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :filename, null: false
      t.string :content_type, null: false
      t.bigint :byte_size, null: false
      t.string :checksum, null: false
      t.string :storage_key, null: false
      t.string :scan_status, null: false, default: "pending"
      t.string :visibility, null: false, default: "internal"
      t.timestamps
    end
    add_index :documents, %i[organization_id person_id]
    add_index :documents, %i[organization_id id], unique: true, name: "index_documents_tenant_pk"
    add_index :documents, %i[organization_id scan_status]
    add_foreign_key :documents, :organizations, column: :organization_id
    add_foreign_key :documents, :people,
                    column: %i[organization_id person_id], primary_key: %i[organization_id id],
                    name: "fk_documents_people_tenant"
  end
end
