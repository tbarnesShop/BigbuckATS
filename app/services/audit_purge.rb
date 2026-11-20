# frozen_string_literal: true

# Called only by maintenance/reset processes. The session flag prevents accidental
# deletion; MySQL grants provide the boundary against the application account.
class AuditPurge
  class MaintenanceRequired < StandardError; end

  def self.ensure_access!
    ActiveRecord::Base.connection.execute("DELETE FROM audit_events WHERE 1 = 0")
  rescue ActiveRecord::StatementInvalid => error
    raise MaintenanceRequired, "Use a maintenance database account for audit cleanup" if error.cause.respond_to?(:error_number) && [ 1142, 1143 ].include?(error.cause.error_number)
    raise
  end

  def self.with_access
    ensure_access!
    connection = ActiveRecord::Base.connection
    previous = connection.select_value("SELECT @bigbuck_audit_purge")
    connection.execute("SET @bigbuck_audit_purge = 1")
    begin
      yield
    ensure
      connection.execute("SET @bigbuck_audit_purge = #{connection.quote(previous)}")
    end
  end
end
