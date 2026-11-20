# frozen_string_literal: true

# C2: the send queue grows the fields it needs to retry safely (a pre-generated
# Message-ID), and opt-outs become a suppression list keyed by a digest so an
# erased person's address stays suppressed without keeping the address.
class CrmC2SendQueue < ActiveRecord::Migration[8.1]
  def change
    change_table :scheduled_messages, bulk: true do |t|
      t.string :rfc822_message_id
      t.string :message_type
      t.string :defer_reason
      t.string :last_error
      t.string :communication_id, limit: 36
      t.datetime :sent_at, precision: 6
    end

    create_table :opt_outs, id: { type: :string, limit: 36 } do |t|
      t.string :organization_id, limit: 36, null: false
      t.string :person_id, limit: 36
      t.string :email_digest, null: false
      t.string :source, null: false
      t.timestamps precision: 6
    end
    add_index :opt_outs, %i[organization_id id], unique: true, name: "index_opt_outs_tenant_pk"
    add_index :opt_outs, %i[organization_id email_digest], unique: true, name: "index_opt_outs_digest"
    add_foreign_key :opt_outs, :organizations, name: "fk_opt_outs_organizations"
    add_foreign_key :opt_outs, :people, column: %i[organization_id person_id], primary_key: %i[organization_id id],
      name: "fk_opt_outs_people_tenant"
  end
end
