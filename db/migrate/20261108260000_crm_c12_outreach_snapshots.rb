# frozen_string_literal: true

# C12: one row per org (and optionally per sequence) per day with the outreach funnel numbers, so
# trends stay cheap to read and survive later edits to the underlying records.
class CrmC12OutreachSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :outreach_snapshots, id: { type: :string, limit: 36 } do |t|
      t.string :organization_id, limit: 36, null: false
      t.date :snapshot_on, null: false
      t.string :sequence_id, limit: 36
      t.string :scope_key, limit: 40, null: false
      t.json :metrics, null: false
      t.timestamps precision: 6
    end
    add_index :outreach_snapshots, %i[organization_id id], unique: true, name: "index_outreach_snapshots_tenant_pk"
    add_index :outreach_snapshots, %i[organization_id scope_key snapshot_on], unique: true, name: "index_outreach_snapshots_day"
    add_foreign_key :outreach_snapshots, :organizations, name: "fk_outreach_snapshots_organizations"
    add_foreign_key :outreach_snapshots, :sequences, column: %i[organization_id sequence_id], primary_key: %i[organization_id id],
      name: "fk_outreach_snapshots_sequences_tenant"
  end
end
