class CreateDemoTemplateSnapshots < ActiveRecord::Migration[8.1]
  def change
    # Platform metadata like demo_sandboxes: the lab dataset, seeded once and copied into each sandbox.
    create_table :demo_template_snapshots, id: false do |t|
      t.string :key, limit: 32, primary_key: true
      t.string :fingerprint, limit: 64, null: false
      t.datetime :seeded_at, null: false
      t.binary :payload, size: :long, null: false
      t.json :blob_ids
      t.integer :row_count, null: false, default: 0
      t.integer :byte_size, null: false, default: 0
      t.timestamps
    end
  end
end
