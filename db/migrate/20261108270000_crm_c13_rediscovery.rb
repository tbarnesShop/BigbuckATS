# frozen_string_literal: true

# C13: explicit job criteria (must / nice) and a review queue of rediscovered people per job.
class CrmC13Rediscovery < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :criteria, :json

    create_table :rediscovery_candidates, id: { type: :string, limit: 36 } do |t|
      t.string :organization_id, limit: 36, null: false
      t.string :job_id, limit: 36, null: false
      t.string :person_id, limit: 36, null: false
      t.string :status, null: false, default: "pending"
      t.string :bucket, null: false
      t.integer :score, null: false, default: 0
      t.json :verdicts, null: false
      t.json :reasons, null: false
      t.text :feedback
      t.string :reviewed_by_user_id, limit: 36
      t.datetime :reviewed_at, precision: 6
      t.string :found_by_agent_id, limit: 36
      t.timestamps precision: 6
    end
    add_index :rediscovery_candidates, %i[organization_id id], unique: true, name: "index_rediscovery_candidates_tenant_pk"
    add_index :rediscovery_candidates, %i[organization_id job_id person_id], unique: true, name: "index_rediscovery_candidates_pair"
    add_index :rediscovery_candidates, %i[organization_id job_id status score], name: "index_rediscovery_candidates_queue"
    add_foreign_key :rediscovery_candidates, :organizations, name: "fk_rediscovery_candidates_organizations"
    add_foreign_key :rediscovery_candidates, :jobs, column: %i[organization_id job_id], primary_key: %i[organization_id id],
      name: "fk_rediscovery_candidates_jobs_tenant"
    add_foreign_key :rediscovery_candidates, :people, column: %i[organization_id person_id], primary_key: %i[organization_id id],
      name: "fk_rediscovery_candidates_people_tenant"
  end
end
