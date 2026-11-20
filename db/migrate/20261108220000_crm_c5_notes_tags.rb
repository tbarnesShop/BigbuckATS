# frozen_string_literal: true

# C5: notes on a person (author, optional agent, pinned) and an org-managed tag vocabulary.
class CrmC5NotesTags < ActiveRecord::Migration[8.1]
  def change
    create_table :person_notes, id: { type: :string, limit: 36 } do |t|
      t.string :organization_id, limit: 36, null: false
      t.string :person_id, limit: 36, null: false
      t.string :author_user_id, limit: 36
      t.string :agent_id, limit: 36
      t.text :body, null: false
      t.boolean :pinned, null: false, default: false
      t.timestamps precision: 6
    end
    add_index :person_notes, %i[organization_id id], unique: true, name: "index_person_notes_tenant_pk"
    add_index :person_notes, %i[organization_id person_id pinned created_at], name: "index_person_notes_feed"
    add_foreign_key :person_notes, :organizations, name: "fk_person_notes_organizations"
    add_foreign_key :person_notes, :people, column: %i[organization_id person_id], primary_key: %i[organization_id id],
      name: "fk_person_notes_people_tenant"

    create_table :tags, id: { type: :string, limit: 36 } do |t|
      t.string :organization_id, limit: 36, null: false
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :color, null: false, default: "#64748b"
      t.timestamps precision: 6
    end
    add_index :tags, %i[organization_id id], unique: true, name: "index_tags_tenant_pk"
    add_index :tags, %i[organization_id normalized_name], unique: true, name: "index_tags_name"
    add_foreign_key :tags, :organizations, name: "fk_tags_organizations"

    create_table :person_tags, id: { type: :string, limit: 36 } do |t|
      t.string :organization_id, limit: 36, null: false
      t.string :person_id, limit: 36, null: false
      t.string :tag_id, limit: 36, null: false
      t.string :added_by_user_id, limit: 36
      t.timestamps precision: 6
    end
    add_index :person_tags, %i[organization_id id], unique: true, name: "index_person_tags_tenant_pk"
    add_index :person_tags, %i[organization_id person_id tag_id], unique: true, name: "index_person_tags_pair"
    add_index :person_tags, %i[organization_id tag_id], name: "index_person_tags_tag"
    add_foreign_key :person_tags, :organizations, name: "fk_person_tags_organizations"
    add_foreign_key :person_tags, :people, column: %i[organization_id person_id], primary_key: %i[organization_id id],
      name: "fk_person_tags_people_tenant"
    add_foreign_key :person_tags, :tags, column: %i[organization_id tag_id], primary_key: %i[organization_id id],
      name: "fk_person_tags_tags_tenant"
  end
end
