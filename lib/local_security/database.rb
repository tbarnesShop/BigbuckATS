# frozen_string_literal: true

require "mysql2"
require "digest"
require "json"
require "openssl"
require "securerandom"
require "fileutils"
require "tempfile"
require "uri"
require "time"

module LocalSecurity
  class Error < StandardError; end

  # Local accounts, confined to one owned sandbox database. Credentials never
  # appear in argv or output, and runtime children inherit only runtime secrets.
  class Database
    ROOT = File.expand_path("../..", __dir__)
    STATE = File.join(ROOT, "tmp/local-security")
    PROFILES = %w[runtime migrator maintenance].freeze

    attr_reader :name, :directory

    def initialize(name = ENV.fetch("LOCAL_SECURITY_DATABASE", "bigbuck_local_security"))
      raise Error, "Only disposable local/recovery database names are allowed" unless name.match?(/\Abigbuck_(?:local_[a-z0-9_]+|recovery_[a-f0-9]{12})\z/) && name.length <= 63
      @name = name
      @directory = File.join(STATE, name)
    end

    def self.admin_options
      host = ENV.fetch("LOCAL_MYSQL_ADMIN_HOST", ENV["LOCAL_MYSQL_ADMIN_SOCKET"] ? "localhost" : "127.0.0.1")
      raise Error, "Local tooling requires a loopback MySQL host" unless %w[127.0.0.1 localhost].include?(host)
      { "host" => host, "port" => Integer(ENV.fetch("LOCAL_MYSQL_ADMIN_PORT", "3306")),
        "username" => ENV.fetch("LOCAL_MYSQL_ADMIN_USER", "root"),
        "password" => ENV.fetch("LOCAL_MYSQL_ADMIN_PASSWORD", ""),
        "socket" => ENV["LOCAL_MYSQL_ADMIN_SOCKET"] }.compact
    end

    def self.client(options)
      Mysql2::Client.new(**options.transform_keys(&:to_sym), reconnect: false)
    end

    def profile(role)
      raise Error, "Unknown database profile" unless PROFILES.include?(role)
      path = File.join(directory, "#{role}.json")
      raise Error, "Database credentials must be private" unless (File.stat(path).mode & 0077).zero?
      options = JSON.parse(File.read(path))
      expected_user = "bb_#{Digest::SHA256.hexdigest(name)[0, 12]}_#{role}"
      unless options["database"] == name && options["username"] == expected_user &&
          %w[localhost 127.0.0.1].include?(options["host"]) && options["password"].to_s.match?(/\A[a-f0-9]{64}\z/)
        raise Error, "Database profile does not match the owned local sandbox"
      end
      options
    end

    def connect(role)
      connection = self.class.client(profile(role))
      yield connection
    ensure
      connection&.close
    end

    def provision!(schema: File.join(ROOT, "db/structure.sql"))
      admin = self.class.client(self.class.admin_options)
      # A loopback connection forwarded into Docker arrives from its bridge.
      # Grant that exact observed origin, never a wildcard account host.
      observed_host = admin.query("SELECT SUBSTRING_INDEX(USER(), '@', -1) AS host").first.fetch("host")
      raise Error, "Unexpected local MySQL client address" unless observed_host.match?(/\A(?:localhost|[0-9a-fA-F:.]+)\z/)
      account_hosts = (%w[localhost 127.0.0.1] + [ observed_host ]).uniq
      server = admin.query("SELECT @@log_bin AS logging, @@log_bin_trust_function_creators AS trusted").first
      if server.fetch("logging") == 1 && server.fetch("trusted") == 0
        raise Error, "Local MySQL requires log_bin_trust_function_creators=1 for the migration account to create audit triggers"
      end
      existed = admin.query("SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='#{name}'").any?
      raise Error, "Existing database is not owned by this local tool" if existed && !File.exist?(File.join(directory, "runtime.json"))
      FileUtils.mkdir_p(directory, mode: 0700)
      admin.query("CREATE DATABASE IF NOT EXISTS `#{name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci")
      PROFILES.each do |role|
        path = File.join(directory, "#{role}.json")
        unless File.exist?(path)
          options = self.class.admin_options.merge("database" => name,
            "username" => "bb_#{Digest::SHA256.hexdigest(name)[0, 12]}_#{role}", "password" => SecureRandom.hex(32))
          File.write(path, JSON.pretty_generate(options), mode: "wx", perm: 0600)
        end
        options = profile(role)
        account_hosts.each do |host|
          account = "'#{options.fetch('username')}'@'#{host}'"
          admin.query("CREATE USER IF NOT EXISTS #{account} IDENTIFIED BY '#{admin.escape(options.fetch('password'))}'")
          admin.query("GRANT ALL PRIVILEGES ON `#{name}`.* TO #{account}") if role == "migrator"
        end
      end
      # Keep the schema import on the migrator connection, never the administrator.
      connect("migrator") do |client|
        mysql_command("mysql", "migrator", input: schema) if client.query("SHOW TABLES").none?
        unless client.query("SHOW TABLES LIKE 'schema_migrations'").any? && client.query("SHOW TRIGGERS WHERE `Table` = 'audit_events'").count == 2
          raise Error, "Incomplete local schema import; remove only this owned disposable database and retry setup"
        end
      end
      tables = admin.query("SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='#{name}'").map { |row| row.fetch("TABLE_NAME") }
      %w[runtime maintenance].each do |role|
        account_hosts.each do |host|
          account = "'#{profile(role).fetch('username')}'@'#{host}'"
          # Refresh grants after migrations, including newly added tables.
          admin.query("REVOKE ALL PRIVILEGES, GRANT OPTION FROM #{account}")
          tables.each do |table|
            permissions = if table == "audit_events"
              role == "runtime" ? "SELECT, INSERT" : "SELECT, INSERT, DELETE"
            else
              "SELECT, INSERT, UPDATE, DELETE"
            end
            admin.query("GRANT #{permissions} ON `#{name}`.`#{table.gsub("`", "``")}` TO #{account}")
          end
        end
      end
      profile("runtime")
      puts "Provisioned #{name}: runtime, migrator and maintenance profiles (private files)."
    ensure
      admin&.close
    end

    def child_environment(role, extra = {})
      options = profile(role)
      url = "mysql2://#{URI.encode_www_form_component(options.fetch('username'))}:#{options.fetch('password')}@#{options.fetch('host')}:#{options.fetch('port')}/#{name}"
      url += "?#{URI.encode_www_form(socket: options['socket']).gsub('+', '%20')}" if options["socket"]
      environment = ENV.keys.grep(/\ALOCAL_MYSQL_ADMIN_/).to_h { |key| [ key, nil ] }
      environment.merge("DATABASE_URL" => url, "MYSQL_USER" => options.fetch("username"),
        "MYSQL_PASSWORD" => options.fetch("password"), "RAILS_ENV" => ENV.fetch("RAILS_ENV", "development"),
        "LOCAL_SECURITY_PROFILE" => role, "LOCAL_SECURITY_DATABASE" => name,
        "BIGBUCK_LOCAL_STORAGE_ROOT" => File.join(directory, "storage"), "BUNDLE_GEMFILE" => File.join(ROOT, "Gemfile")).merge(extra)
    end

    def run!(role, *command, extra: {})
      require_ready! if role == "runtime" && name.start_with?("bigbuck_recovery_")
      raise Error, "Command failed: #{command.first}" unless system(child_environment(role, extra), *command, chdir: ROOT)
    end

    def assert_runtime_permissions!
      connect("runtime") do |client|
        client.query("SELECT id FROM audit_events LIMIT 0")
        [ "DELETE FROM audit_events WHERE 1=0", "UPDATE audit_events SET action='invalid' WHERE 1=0" ].each do |sql|
          self.class.expect_denied!(client, sql)
        end
      end
    end

    def self.expect_denied!(client, sql)
      client.query(sql)
      raise Error, "Database privilege boundary failed"
    rescue Mysql2::Error => error
      raise unless [ 1044, 1142, 1143, 1227 ].include?(error.error_number)
    end

    def verify!
      id = SecureRandom.uuid
      audit_id = SecureRandom.uuid
      now = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
      connect("runtime") do |client|
        client.query("INSERT INTO organizations (id,name,slug,created_at,updated_at) VALUES ('#{id}','Privilege canary','privilege-#{id}','#{now}','#{now}')")
        client.query("UPDATE organizations SET name='Updated canary' WHERE id='#{id}'")
        client.query("INSERT INTO audit_events (id,organization_id,action,resource_type,resource_id,created_at,updated_at) VALUES ('#{audit_id}','#{id}','local.verified','Organization','#{id}','#{now}','#{now}')")
        client.query("SET @bigbuck_audit_purge=1")
        self.class.expect_denied!(client, "DELETE FROM audit_events WHERE id='#{audit_id}'")
        self.class.expect_denied!(client, "UPDATE audit_events SET action='tampered' WHERE id='#{audit_id}'")
        self.class.expect_denied!(client, "CREATE TABLE local_privilege_probe (id int)")
        self.class.expect_denied!(client, "GRANT SELECT ON `#{name}`.* TO '#{profile('runtime').fetch('username')}'@'localhost'")
        raise Error, "Audit record changed" unless client.query("SELECT action FROM audit_events WHERE id='#{audit_id}'").first.fetch("action") == "local.verified"
      end
      connect("migrator") do |client|
        client.query("CREATE TABLE local_privilege_probe (id int)")
        client.query("DROP TABLE local_privilege_probe")
      end
      connect("maintenance") do |client|
        self.class.expect_append_only!(client, "DELETE FROM audit_events WHERE id='#{audit_id}'")
        client.query("SET @bigbuck_audit_purge=1")
        client.query("DELETE FROM audit_events WHERE id='#{audit_id}'")
        client.query("SET @bigbuck_audit_purge=NULL")
        client.query("DELETE FROM organizations WHERE id='#{id}'")
      end
      puts "Verified application CRUD, append-only audit, blocked flag bypass/DDL/grants, and maintenance/migration access."
    ensure
      if id
        connect("maintenance") do |client|
          client.query("SET @bigbuck_audit_purge=1")
          client.query("DELETE FROM audit_events WHERE organization_id='#{id}'")
          client.query("DELETE FROM organizations WHERE id='#{id}'")
        end
        connect("migrator") { |client| client.query("DROP TABLE IF EXISTS local_privilege_probe") }
      end
    end

    def self.expect_append_only!(client, sql)
      client.query(sql)
      raise Error, "Append-only trigger failed"
    rescue Mysql2::Error => error
      raise unless error.sql_state == "45000"
    end

    def mysql_command(program, role, input: nil, output: nil, arguments: [])
      options = profile(role)
      Tempfile.create("bigbuck-mysql") do |config|
        values = { "user" => options.fetch("username"), "password" => options.fetch("password"),
          "host" => options.fetch("host"), "port" => options.fetch("port"), "socket" => options["socket"] }.compact
        config.write("[client]\n" + values.map { |key, value| "#{key}=\"#{value.to_s.gsub(/[\\\"]/) { |char| "\\#{char}" }}\"\n" }.join)
        config.flush
        io = output ? File.open(output, "wx", 0600) : File::NULL
        pid = Process.spawn(program, "--defaults-file=#{config.path}", *arguments, name,
          in: input || File::NULL, out: io)
        _, status = Process.wait2(pid)
        raise Error, "#{program} failed" unless status.success?
      ensure
        io&.close if io.is_a?(File)
      end
    end

    def self.signing_key
      FileUtils.mkdir_p(STATE, mode: 0700)
      path = File.join(STATE, "recovery-signing.key")
      File.write(path, SecureRandom.hex(32), mode: "wx", perm: 0600) unless File.exist?(path)
      File.read(path)
    end

    def self.write_signed(path, payload)
      data = JSON.generate(payload)
      File.write(path, JSON.generate("data" => data, "hmac" => OpenSSL::HMAC.hexdigest("SHA256", signing_key, data)), perm: 0600)
      File.chmod(0600, path)
    end

    def self.read_signed(path)
      raise Error, "Recovery metadata too large" if File.size(path) > 5_000_000
      envelope = JSON.parse(File.read(path))
      raise Error, "Invalid recovery metadata" unless envelope.is_a?(Hash) && envelope["data"].is_a?(String) && envelope["hmac"].is_a?(String)
      expected = OpenSSL::HMAC.hexdigest("SHA256", signing_key, envelope.fetch("data"))
      raise Error, "Recovery metadata signature is invalid" unless envelope.fetch("hmac").is_a?(String) && OpenSSL.fixed_length_secure_compare(expected, envelope.fetch("hmac"))
      JSON.parse(envelope.fetch("data"))
    rescue KeyError, JSON::ParserError, ArgumentError
      raise Error, "Invalid recovery metadata"
    end

    def require_ready!
      ready = self.class.read_signed(File.join(directory, "READY.json"))
      raise Error, "Recovered database is not verified ready" unless ready["database"] == name && ready["verified"] == true
    rescue Errno::ENOENT
      raise Error, "Recovered database is quarantined until erasures are replayed and verified"
    end
  end
end
