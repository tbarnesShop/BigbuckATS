class HardenSecurityBoundaries < ActiveRecord::Migration[8.1]
  def change
    add_column :idempotency_keys, :request_fingerprint, :string, limit: 64
    # Repair already-applied environments without changing intentional posting overrides.
    change_column_default :postings, :audience, from: "public", to: nil
    create_table :oauth_transactions, id: { type: :string, limit: 36 } do |t|
      t.string :state_digest, null: false, limit: 64
      t.string :browser_digest, null: false, limit: 64
      t.json :payload, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :oauth_transactions, :state_digest, unique: true
    add_index :oauth_transactions, :expires_at
  end
end
