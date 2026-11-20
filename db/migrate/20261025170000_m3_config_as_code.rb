# frozen_string_literal: true

class M3ConfigAsCode < ActiveRecord::Migration[8.1]
  def change
    create_table :config_objects, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :kind, null: false # PipelineTemplate, Dimension, CustomField, ReasonSet, ScorecardTemplate
      t.string :key, null: false
      t.json :spec, null: false
      t.integer :version, null: false, default: 1
      t.string :status, null: false, default: "active" # active | archived
      t.timestamps
    end
    add_index :config_objects, %i[organization_id kind key], unique: true
    add_index :config_objects, %i[organization_id id], unique: true, name: "index_config_objects_tenant_pk"
    add_foreign_key :config_objects, :organizations, column: :organization_id

    create_table :config_revisions, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.integer :number, null: false
      t.string :source, null: false, default: "api" # api | ui | cli | apply
      t.string :actor_id, limit: 36
      t.string :manifest_hash, null: false
      t.json :manifest, null: false
      t.timestamps
    end
    add_index :config_revisions, %i[organization_id number], unique: true
    add_index :config_revisions, %i[organization_id id], unique: true, name: "index_config_revisions_tenant_pk"
    add_foreign_key :config_revisions, :organizations, column: :organization_id

    create_table :config_plans, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :status, null: false, default: "open" # open | applied | refused
      t.json :desired_manifest, null: false
      t.json :change_set, null: false # [{kind,key,op,from_version,to_spec}]
      t.json :object_versions, null: false # {"PipelineTemplate/eng": 3}
      t.string :manifest_hash, null: false
      t.string :refuse_reason
      t.timestamps
    end
    add_index :config_plans, %i[organization_id id], unique: true, name: "index_config_plans_tenant_pk"
    add_foreign_key :config_plans, :organizations, column: :organization_id
  end
end
