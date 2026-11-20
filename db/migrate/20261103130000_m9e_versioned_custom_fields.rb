# frozen_string_literal: true

# M9e: custom fields as a versioned schema. Definitions are archived, never
# deleted; every definition change is a new version row; values remember the
# definition version they were written under; type changes run as previewed
# migrations over existing values.
class M9eVersionedCustomFields < ActiveRecord::Migration[8.1]
  def change
    change_table :custom_fields, bulk: true do |t|
      t.text :description
      t.json :options
      t.string :reference_type
      t.boolean :required, null: false, default: false
      t.boolean :filterable, null: false, default: false
      t.integer :display_order, null: false, default: 0
      t.string :status, null: false, default: "active" # active | archived
      t.integer :version, null: false, default: 1
      t.datetime :archived_at
    end

    create_table :custom_field_versions, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :custom_field_id, null: false, limit: 36
      t.integer :version, null: false
      t.string :change_kind, null: false # created | updated | type_changed | archived | restored
      t.json :definition, null: false
      t.json :migration_summary
      t.string :actor_id, limit: 36
      t.timestamps
    end
    add_index :custom_field_versions, %i[organization_id custom_field_id version], unique: true,
                                                                                  name: "index_custom_field_versions_unique"
    add_index :custom_field_versions, %i[organization_id id], unique: true, name: "index_custom_field_versions_tenant_pk"
    add_foreign_key :custom_field_versions, :organizations, column: :organization_id
    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          ALTER TABLE custom_field_versions ADD CONSTRAINT fk_custom_field_versions_fields_tenant
            FOREIGN KEY (organization_id, custom_field_id) REFERENCES custom_fields (organization_id, id)
        SQL
        # Version 1 for every existing definition.
        execute <<~SQL.squish
          INSERT INTO custom_field_versions (id, organization_id, custom_field_id, version, change_kind, definition, created_at, updated_at)
          SELECT UUID(), organization_id, id, 1, 'created',
                 JSON_OBJECT('key', `key`, 'entity', entity, 'label', label, 'field_type', field_type,
                             'data_class', data_class, 'options', NULL, 'required', FALSE),
                 created_at, NOW(6)
          FROM custom_fields
        SQL
      end
    end

    change_table :custom_field_values, bulk: true do |t|
      t.integer :field_version, null: false, default: 1
      t.integer :version, null: false, default: 1
    end
    add_index :custom_field_values, %i[organization_id entity_type entity_id], name: "index_custom_field_values_entity"
  end
end
