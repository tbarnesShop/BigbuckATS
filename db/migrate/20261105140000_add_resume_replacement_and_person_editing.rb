# frozen_string_literal: true

class AddResumeReplacementAndPersonEditing < ActiveRecord::Migration[8.1]
  def up
    add_column :documents, :superseded_at, :datetime
    # Existing system roles receive the same person-editing capabilities as new organizations.
    execute <<~SQL
      INSERT INTO role_permissions (id, organization_id, role_id, permission, created_at, updated_at)
      SELECT UUID(), roles.organization_id, roles.id, capabilities.permission, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM roles
      CROSS JOIN (SELECT 'person.edit_details' AS permission UNION ALL SELECT 'document.upload') capabilities
      WHERE roles.system = TRUE AND roles.`key` = 'hiring_manager'
        AND NOT EXISTS (SELECT 1 FROM role_permissions existing WHERE existing.role_id = roles.id AND existing.permission = capabilities.permission)
    SQL
  end

  def down
    remove_column :documents, :superseded_at
  end
end
