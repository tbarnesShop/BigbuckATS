# frozen_string_literal: true

# Recruiters build and send offers, so they see the compensation on them. Existing system recruiter roles
# get the permission the preset now includes.
class RecruitersViewOfferCompensation < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO role_permissions (id, organization_id, role_id, permission, created_at, updated_at)
      SELECT UUID(), roles.organization_id, roles.id, 'offer.view_compensation', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM roles
      WHERE roles.system = TRUE AND roles.`key` = 'recruiter'
        AND NOT EXISTS (
          SELECT 1 FROM role_permissions existing
          WHERE existing.role_id = roles.id AND existing.permission = 'offer.view_compensation'
        )
    SQL
  end

  def down
    execute <<~SQL
      DELETE role_permissions FROM role_permissions
      JOIN roles ON roles.id = role_permissions.role_id
      WHERE roles.system = TRUE AND roles.`key` = 'recruiter' AND role_permissions.permission = 'offer.view_compensation'
    SQL
  end
end
