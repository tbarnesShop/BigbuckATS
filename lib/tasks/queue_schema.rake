# In production the primary and queue configs point at the same MySQL database, so db:prepare sees
# that database as already initialised and never loads db/queue_schema.rb. Without the Solid Queue
# tables the in-Puma supervisor crashes on boot and takes Puma (and the request) down with it.
namespace :db do
  desc "Load db/queue_schema.rb when the Solid Queue tables are missing"
  task ensure_queue_schema: :load_config do
    config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "queue")
    schema = Rails.root.join("db/queue_schema.rb")
    next unless config && schema.exist?

    ActiveRecord::Base.establish_connection(config)
    next if ActiveRecord::Base.connection.table_exists?("solid_queue_jobs")

    ActiveRecord::Tasks::DatabaseTasks.load_schema(config, :ruby, schema.to_s)
  end
end

Rake::Task["db:prepare"].enhance { Rake::Task["db:ensure_queue_schema"].invoke } if Rake::Task.task_defined?("db:prepare")
