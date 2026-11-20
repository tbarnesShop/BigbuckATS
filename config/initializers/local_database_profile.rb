# The local launcher verifies the actual Rails identity, not just a profile label.
if ENV["LOCAL_SECURITY_PROFILE"] == "runtime"
  Rails.application.config.after_initialize do
    database = LocalSecurity::Database.new
    config = ActiveRecord::Base.connection_db_config
    unless config.database == database.name && config.configuration_hash[:username] == database.profile("runtime").fetch("username")
      raise LocalSecurity::Error, "Runtime database identity does not match the local runtime profile"
    end
    database.assert_runtime_permissions!
    database.require_ready! if database.name.start_with?("bigbuck_recovery_")
  end
end
