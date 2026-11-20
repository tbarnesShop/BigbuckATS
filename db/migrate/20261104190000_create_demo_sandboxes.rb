class CreateDemoSandboxes < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_sandboxes, id: false do |t|
      t.string :surface, limit: 12, primary_key: true
      t.string :organization_id, limit: 36
      t.integer :generation, null: false, default: 1
      t.string :state, null: false, default: "initializing"
      t.datetime :seeded_at
      t.datetime :resets_at
      t.timestamps
      t.index :organization_id, unique: true
    end
  end
end
