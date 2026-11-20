# frozen_string_literal: true

class M2Pipelines < ActiveRecord::Migration[8.1]
  def change
    create_table :pipeline_templates, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :name, null: false
      t.string :object_type, null: false, default: "job" # job | project
      t.integer :published_version, null: false, default: 0
      t.timestamps
    end
    add_index :pipeline_templates, %i[organization_id key], unique: true
    add_index :pipeline_templates, %i[organization_id id], unique: true, name: "index_pipeline_templates_tenant_pk"
    add_foreign_key :pipeline_templates, :organizations, column: :organization_id

    create_table :pipeline_template_versions, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :pipeline_template_id, null: false, limit: 36
      t.integer :version, null: false
      t.json :stages, null: false # [{key,name,type,interviews:[{key,name,...}]}]
      t.datetime :published_at, null: false
      t.timestamps
    end
    add_index :pipeline_template_versions, %i[organization_id pipeline_template_id version],
              unique: true, name: "index_pipeline_template_versions_unique"
    add_index :pipeline_template_versions, %i[organization_id id], unique: true, name: "index_pipeline_template_versions_tenant_pk"
    add_foreign_key :pipeline_template_versions, :organizations, column: :organization_id

    create_table :pipelines, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :scope, null: false # job | project
      t.string :pipeline_template_id, limit: 36
      t.integer :template_version, null: false, default: 0
      t.json :overrides, null: false # [{op, ...}]
      t.integer :version, null: false, default: 1
      t.boolean :needs_review, null: false, default: false
      t.json :resolved_stages, null: false
      t.timestamps
    end
    add_index :pipelines, %i[organization_id id], unique: true, name: "index_pipelines_tenant_pk"
    add_foreign_key :pipelines, :organizations, column: :organization_id

    create_table :jobs, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :title, null: false
      t.string :status, null: false, default: "draft"
      t.string :pipeline_id, null: false, limit: 36
      t.boolean :confidential, null: false, default: false
      t.string :code_name
      t.integer :version, null: false, default: 1
      t.timestamps
    end
    add_index :jobs, %i[organization_id id], unique: true, name: "index_jobs_tenant_pk"
    add_index :jobs, %i[organization_id status]
    add_foreign_key :jobs, :organizations, column: :organization_id
    add_foreign_key :jobs, :pipelines, column: %i[organization_id pipeline_id], primary_key: %i[organization_id id], name: "fk_jobs_pipelines_tenant"

    create_table :applications, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :job_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :pipeline_id, null: false, limit: 36
      t.integer :pipeline_version, null: false
      t.string :current_stage_key, null: false
      t.string :status, null: false, default: "active" # active | rejected | withdrawn | hired
      t.string :source_project_member_id, limit: 36
      t.integer :version, null: false, default: 1
      t.timestamps
    end
    add_index :applications, %i[organization_id id], unique: true, name: "index_applications_tenant_pk"
    add_index :applications, %i[organization_id job_id]
    add_index :applications, %i[organization_id person_id]
    add_foreign_key :applications, :organizations, column: :organization_id
    add_foreign_key :applications, :jobs, column: %i[organization_id job_id], primary_key: %i[organization_id id], name: "fk_applications_jobs_tenant"
    add_foreign_key :applications, :people, column: %i[organization_id person_id], primary_key: %i[organization_id id], name: "fk_applications_people_tenant"

    create_table :projects, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :name, null: false
      t.string :pipeline_id, limit: 36
      t.string :job_id, limit: 36
      t.boolean :confidential, null: false, default: false
      t.integer :version, null: false, default: 1
      t.timestamps
    end
    add_index :projects, %i[organization_id id], unique: true, name: "index_projects_tenant_pk"
    add_foreign_key :projects, :organizations, column: :organization_id

    create_table :project_members, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :project_id, null: false, limit: 36
      t.string :person_id, null: false, limit: 36
      t.string :pipeline_id, limit: 36
      t.integer :pipeline_version
      t.string :current_stage_key
      t.string :status, null: false, default: "active"
      t.string :converted_application_id, limit: 36
      t.integer :version, null: false, default: 1
      t.timestamps
    end
    add_index :project_members, %i[organization_id project_id person_id], unique: true, name: "index_project_members_unique"
    add_index :project_members, %i[organization_id id], unique: true, name: "index_project_members_tenant_pk"
    add_foreign_key :project_members, :organizations, column: :organization_id
    add_foreign_key :project_members, :projects, column: %i[organization_id project_id], primary_key: %i[organization_id id], name: "fk_project_members_projects_tenant"
    add_foreign_key :project_members, :people, column: %i[organization_id person_id], primary_key: %i[organization_id id], name: "fk_project_members_people_tenant"

    create_table :stage_transitions, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :subject_type, null: false # Application | ProjectMember
      t.string :subject_id, null: false, limit: 36
      t.string :from_stage_key
      t.string :to_stage_key, null: false
      t.string :command, null: false # move | reject | unreject | withdraw | hire
      t.string :reason
      t.string :actor_id, limit: 36
      t.timestamps
    end
    add_index :stage_transitions, %i[organization_id subject_type subject_id], name: "index_stage_transitions_subject"
    add_index :stage_transitions, %i[organization_id id], unique: true, name: "index_stage_transitions_tenant_pk"
    add_foreign_key :stage_transitions, :organizations, column: :organization_id

    create_table :postings, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :job_id, null: false, limit: 36
      t.string :title, null: false
      t.string :status, null: false, default: "draft" # draft | published | closed
      t.timestamps
    end
    add_index :postings, %i[organization_id id], unique: true, name: "index_postings_tenant_pk"
    add_foreign_key :postings, :organizations, column: :organization_id
    add_foreign_key :postings, :jobs, column: %i[organization_id job_id], primary_key: %i[organization_id id], name: "fk_postings_jobs_tenant"
  end
end
