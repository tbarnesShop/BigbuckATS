# frozen_string_literal: true

# CRM C1: one mail transport seam. Mailboxes name their provider and keep sync
# cursors; communications keep RFC 822 threading ids; sandbox_messages is the
# in-product mail store the Sandbox transport writes to.
class CrmC1MailTransport < ActiveRecord::Migration[8.1]
  def change
    change_table :mailboxes, bulk: true do |t|
      t.string :provider, null: false, default: "gmail" # sandbox | gmail
      t.string :history_cursor
      t.datetime :watch_expires_at
      t.string :last_sync_status
      t.datetime :last_synced_at
    end

    change_table :communications, bulk: true do |t|
      t.string :rfc822_message_id
      t.string :in_reply_to
      t.string :sent_by_user_id, limit: 36
      t.string :agent_id, limit: 36
      t.string :on_behalf_of_user_id, limit: 36
      t.string :classification
    end
    add_index :communications, %i[organization_id rfc822_message_id], name: "index_communications_rfc822"
    add_index :communications, %i[organization_id thread_id], name: "index_communications_thread"

    create_table :sandbox_messages, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :mailbox_id, null: false, limit: 36
      t.string :direction, null: false # outbound | inbound
      t.string :rfc822_message_id, null: false
      t.string :in_reply_to
      t.string :thread_id, null: false
      t.string :from_address, null: false
      t.string :to_address, null: false
      t.string :subject
      t.text :mime, size: :medium
      t.datetime :delivered_at, null: false
      t.timestamps
    end
    add_index :sandbox_messages, %i[organization_id id], unique: true, name: "index_sandbox_messages_tenant_pk"
    add_index :sandbox_messages, %i[organization_id mailbox_id created_at], name: "index_sandbox_messages_mailbox"
    add_index :sandbox_messages, %i[organization_id rfc822_message_id], unique: true, name: "index_sandbox_messages_rfc822"
    add_index :sandbox_messages, %i[organization_id thread_id], name: "index_sandbox_messages_thread"
    add_foreign_key :sandbox_messages, :organizations, column: :organization_id
    add_foreign_key :sandbox_messages, :mailboxes, column: %i[organization_id mailbox_id], primary_key: %i[organization_id id],
      name: "fk_sandbox_messages_mailboxes_tenant"
  end
end
