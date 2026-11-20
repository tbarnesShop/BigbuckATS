class CreateOauthIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_identities, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :membership_id, limit: 36
      t.string :name, null: false
      t.string :issuer, null: false, limit: 255
      t.string :subject, null: false, limit: 255
      t.string :client_id, null: false, limit: 255
      t.string :binding_digest, null: false, limit: 64
      t.string :kind, null: false
      t.json :scopes, null: false
      t.string :status, null: false, default: "active"
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :oauth_identities, :binding_digest, unique: true
    add_index :oauth_identities, [ :organization_id, :id ], unique: true
    add_foreign_key :oauth_identities, :organizations
    add_foreign_key :oauth_identities, :memberships,
      column: [ :organization_id, :membership_id ], primary_key: [ :organization_id, :id ], name: "fk_oauth_identity_membership_tenant"
  end
end
