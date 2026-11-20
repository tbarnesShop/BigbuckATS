require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Private durable storage; downloads require tenant authorization and a clean scan.
  config.active_storage.service = :private_documents

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Cloud Run terminates TLS at the edge.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # Exempt only the health endpoint from HTTPS redirects.
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = :info

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # Queue tables live in the same MySQL database via the `queue` connection (see database.yml).
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }


  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Pin production API hosts with BIGBUCK_ALLOWED_HOSTS.
  config.hosts = ENV.fetch("BIGBUCK_ALLOWED_HOSTS").split(",").map(&:strip).reject(&:empty?)
  raise "BIGBUCK_ALLOWED_HOSTS must contain at least one host" if config.hosts.empty?
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  # Identity (M9a). Never trust tenant/actor headers in production; every request
  # authenticates with a bearer credential. Demo email sign-in is opt-in for demo
  # deployments only (BIGBUCK_DEMO_SIGN_IN=1) and issues short-lived sessions.
  config.x.header_auth = false
  config.x.demo_sign_in = ENV["BIGBUCK_DEMO_SIGN_IN"] == "1"
  # Only for a private deployment (e.g. IAM-only Cloud Run): lets anyone who can reach the site apply on
  # the lab careers page and accept a lab offer link. Leave unset on a public demo.
  config.x.demo_candidate_writes = ENV["BIGBUCK_DEMO_CANDIDATE_WRITES"] == "1"

  # GraphQL: browser sessions may only run registered (persisted) queries.
  config.x.graphql_persisted_only_for_sessions = true
end
