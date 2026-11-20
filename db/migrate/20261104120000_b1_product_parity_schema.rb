# frozen_string_literal: true

# B1: columns and the scorecard rubric table behind the recruiter product
# screens (company industry/size, job openings, screening questions on apply,
# archivable message templates, rubric-based scorecards). Additive only.
class B1ProductParitySchema < ActiveRecord::Migration[8.1]
  def change
    change_table :companies, bulk: true do |t|
      t.string :industry
      t.string :employee_band
    end
    add_column :jobs, :openings, :integer, null: false, default: 1
    add_column :custom_fields, :show_on_apply, :boolean, null: false, default: false
    add_column :message_templates, :archived_at, :datetime
    add_column :scorecards, :attribute_ratings, :json

    create_table :scorecard_rubrics, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :name, null: false
      t.text :guidance
      t.json :attributes_spec, null: false
      t.timestamps
    end
    add_index :scorecard_rubrics, %i[organization_id key], unique: true
    add_index :scorecard_rubrics, %i[organization_id id], unique: true, name: "index_scorecard_rubrics_tenant_pk"
    add_foreign_key :scorecard_rubrics, :organizations, column: :organization_id
  end
end
