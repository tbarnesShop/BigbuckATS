class AddPostingApplicationForms < ActiveRecord::Migration[8.1]
  def up
    create_table :application_question_templates, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :owner_user_id, null: false, limit: 36
      t.string :name, null: false
      t.string :status, null: false, default: "active"
      t.json :questions, null: false
      t.integer :version, null: false, default: 1
      t.timestamps
    end
    add_index :application_question_templates, [ :organization_id, :id ], unique: true, name: "idx_question_templates_tenant"
    add_foreign_key :application_question_templates, :organizations
    add_foreign_key :application_question_templates, :users, column: :owner_user_id
    add_column :postings, :audience, :string, null: false, default: "public"
    change_column_default :postings, :audience, from: "public", to: nil
    add_column :postings, :questions, :json
    add_column :postings, :template_questions, :json
    add_column :postings, :question_template_id, :string, limit: 36
    add_column :postings, :template_version, :integer
    add_column :postings, :version, :integer, null: false, default: 1
    add_foreign_key :postings, :application_question_templates, column: [ :organization_id, :question_template_id ], primary_key: [ :organization_id, :id ], name: "fk_postings_question_template"
    execute "UPDATE postings JOIN jobs ON postings.job_id = jobs.id AND postings.organization_id = jobs.organization_id SET postings.audience = jobs.careers_visibility"
    add_column :applications, :posting_id, :string, limit: 36
    add_column :applications, :application_form_snapshot, :json
    add_column :applications, :application_answers, :json
    add_foreign_key :applications, :postings, column: [ :organization_id, :posting_id ], primary_key: [ :organization_id, :id ], name: "fk_applications_posting_tenant"
  end

  def down
    remove_foreign_key :applications, name: "fk_applications_posting_tenant"
    remove_column :applications, :posting_id
    remove_column :applications, :application_form_snapshot
    remove_column :applications, :application_answers
    remove_foreign_key :postings, name: "fk_postings_question_template"
    %i[audience questions template_questions question_template_id template_version version].each { |column| remove_column :postings, column }
    drop_table :application_question_templates
  end
end
