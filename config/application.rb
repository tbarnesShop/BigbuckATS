require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)
require_relative "../lib/request_security"

module Bigbuck
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.active_storage.draw_routes = false
    config.middleware.use ActionDispatch::Cookies
    config.middleware.insert_before 0, RequestSecurity
    config.active_job.log_arguments = false
    config.api_only = true
    config.active_record.schema_format = :sql
    config.generators.orm :active_record, primary_key_type: :string
  end
end
