# frozen_string_literal: true

# Feedback permissions for organizations that already exist (new ones get them from
# Permissions::PRESETS): recruiters read every scorecard, owners and admins may correct one.
class FeedbackPermissions < ActiveRecord::Migration[8.1]
  GRANTS = {
    "recruiter" => %w[scorecard.read_all],
    "admin" => %w[scorecard.manage],
    "owner" => %w[scorecard.manage]
  }.freeze

  def up
    GRANTS.each do |role_key, permissions|
      permissions.each do |permission|
        execute(<<~SQL.squish)
          INSERT INTO role_permissions (id, organization_id, role_id, permission, created_at, updated_at)
          SELECT UUID(), roles.organization_id, roles.id, #{quote(permission)}, NOW(6), NOW(6)
          FROM roles
          WHERE roles.`key` = #{quote(role_key)} AND roles.system = 1
            AND NOT EXISTS (
              SELECT 1 FROM role_permissions existing
              WHERE existing.role_id = roles.id AND existing.permission = #{quote(permission)}
            )
        SQL
      end
    end
  end

  def down
    GRANTS.each do |role_key, permissions|
      execute(<<~SQL.squish)
        DELETE role_permissions FROM role_permissions
        JOIN roles ON roles.id = role_permissions.role_id
        WHERE roles.`key` = #{quote(role_key)} AND roles.system = 1
          AND role_permissions.permission IN (#{permissions.map { |p| quote(p) }.join(", ")})
      SQL
    end
  end
end
