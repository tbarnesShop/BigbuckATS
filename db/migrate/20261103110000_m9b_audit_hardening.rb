# frozen_string_literal: true

# M9b: audit history you can rely on.
# - audit_events is append-only, enforced by triggers. The only way to delete is
#   the explicit per-connection purge flag used by demo resets
#   (SET @bigbuck_audit_purge = 1); production grants should also give the app
#   user INSERT/SELECT only on audit_events.
# - audit rows and outbox events carry the dated API version; outbox events also
#   carry who acted and through which surface, for webhook consumers.
class M9bAuditHardening < ActiveRecord::Migration[8.1]
  def up
    add_column :audit_events, :api_version, :string, limit: 32
    add_column :outbox_events, :api_version, :string, limit: 32
    add_column :outbox_events, :actor_type, :string, limit: 32
    add_column :outbox_events, :actor_id, :string, limit: 36
    add_column :outbox_events, :source_surface, :string, limit: 32

    execute <<~SQL
      CREATE TRIGGER audit_events_no_update BEFORE UPDATE ON audit_events
      FOR EACH ROW
      BEGIN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_events is append-only';
      END
    SQL

    execute <<~SQL
      CREATE TRIGGER audit_events_no_delete BEFORE DELETE ON audit_events
      FOR EACH ROW
      BEGIN
        IF COALESCE(@bigbuck_audit_purge, 0) <> 1 THEN
          SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_events is append-only';
        END IF;
      END
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS audit_events_no_delete"
    execute "DROP TRIGGER IF EXISTS audit_events_no_update"
    remove_column :outbox_events, :source_surface
    remove_column :outbox_events, :actor_id
    remove_column :outbox_events, :actor_type
    remove_column :outbox_events, :api_version
    remove_column :audit_events, :api_version
  end
end
