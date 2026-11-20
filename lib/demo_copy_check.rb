# frozen_string_literal: true

# Integrity checks for tenants copied from the lab template snapshot (tests and `bin/rails demo:check`).
module DemoCopyCheck
  module_function

  # Per-table row counts that differ between two tenants: { table => [a, b] }.
  def count_differences(a_id, b_id, conn = ActiveRecord::Base.connection)
    DemoTemplate.tenant_tables(conn).each_with_object({}) do |table, out|
      next if DemoTemplate::SECRET_TABLES.include?(table)

      sql = "SELECT organization_id, COUNT(*) FROM #{conn.quote_table_name(table)} WHERE organization_id IN (#{conn.quote(a_id)}, #{conn.quote(b_id)}) GROUP BY organization_id"
      counts = conn.select_rows(sql).to_h
      a, b = counts.fetch(a_id, 0), counts.fetch(b_id, 0)
      out[table] = [ a, b ] unless a == b
    end
  end

  # Foreign keys from the tenant's rows that point at nothing: ["table.column -> parent", ...].
  def orphans(org_id, conn = ActiveRecord::Base.connection)
    fks = conn.select_rows(<<~SQL.squish)
      SELECT TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME, CONSTRAINT_NAME
      FROM information_schema.KEY_COLUMN_USAGE
      WHERE TABLE_SCHEMA = DATABASE() AND REFERENCED_TABLE_NAME IS NOT NULL AND COLUMN_NAME <> 'organization_id'
    SQL
    tenant = DemoTemplate.tenant_tables(conn)
    fks.filter_map do |table, column, parent, parent_column, _name|
      next unless tenant.include?(table)

      q = ->(name) { conn.quote_table_name(name) }
      missing = conn.select_value(<<~SQL.squish).to_i
        SELECT COUNT(*) FROM #{q[table]} c LEFT JOIN #{q[parent]} p ON p.#{conn.quote_column_name(parent_column)} = c.#{conn.quote_column_name(column)}
        WHERE c.organization_id = #{conn.quote(org_id)} AND c.#{conn.quote_column_name(column)} IS NOT NULL AND p.#{conn.quote_column_name(parent_column)} IS NULL
      SQL
      "#{table}.#{column} -> #{parent} (#{missing})" if missing.positive?
    end
  end

  # Rows of the copy that still mention an id belonging to the source tenant: { table => count }.
  def leaks(source_id, copy_id, conn = ActiveRecord::Base.connection)
    source_ids = DemoTemplate.tenant_tables(conn).flat_map do |table|
      conn.select_values("SELECT id FROM #{conn.quote_table_name(table)} WHERE organization_id = #{conn.quote(source_id)}")
    end.to_set << source_id
    DemoTemplate.tenant_tables(conn).each_with_object({}) do |table, out|
      rows = conn.raw_connection.query("SELECT * FROM #{conn.quote_table_name(table)} WHERE organization_id = #{conn.quote(copy_id)}", cast: false, as: :array).to_a
      hits = rows.count { |row| row.any? { |v| v.is_a?(String) && v.scan(DemoTemplate::UUID).any? { |id| source_ids.include?(id) } } }
      out[table] = hits if hits.positive?
    end
  end
end
