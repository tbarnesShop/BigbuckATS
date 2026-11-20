# frozen_string_literal: true

# Column data-class registry (config/data_classes.yml). Ported from BigBuck-ATS's
# column_data_classes table: every column has a class, and the audit writer
# decides what may reach history from it.
module DataClasses
  CLASSES = %w[internal pii sensitive secret dynamic].freeze
  HASHED = %w[pii sensitive].freeze
  PATH = Rails.root.join("config/data_classes.yml")

  class Unclassified < StandardError; end

  module_function

  def registry
    @registry ||= YAML.safe_load_file(PATH).transform_values { |cols| cols.transform_values(&:to_s) }.freeze
  end

  def reload!
    @registry = nil
  end

  # Class for table.column, or nil when unclassified.
  def lookup(table, column)
    registry.dig(table.to_s, column.to_s)
  end

  # Columns present in the database but missing from the registry.
  def unclassified(connection = ActiveRecord::Base.connection)
    ignored = %w[schema_migrations ar_internal_metadata]
    (connection.tables - ignored).sort.flat_map do |table|
      connection.columns(table).map(&:name).reject { |col| lookup(table, col) }.map { |col| "#{table}.#{col}" }
    end
  end

  def invalid_entries
    registry.flat_map do |table, cols|
      cols.reject { |_col, cls| CLASSES.include?(cls) }.map { |col, cls| "#{table}.#{col}=#{cls}" }
    end
  end
end
