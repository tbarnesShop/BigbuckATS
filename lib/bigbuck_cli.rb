# frozen_string_literal: true

require "thor"

# Thin CLI over the same domain services (M3). Full HTTP client arrives with the SDK.
class BigbuckCli < Thor
  class_option :org, type: :string, required: true, desc: "Organization id"

  desc "config validate PATH", "Validate config YAML documents in PATH"
  def config_validate(path)
    within_org do
      docs = load_docs(path)
      ConfigCompiler.compile(docs)
      puts "OK #{docs.size} documents"
    end
  end

  desc "config plan PATH", "Plan apply for config documents in PATH"
  def config_plan(path)
    within_org do
      plan = ConfigPlanner.plan(documents: load_docs(path))
      puts JSON.pretty_generate(
        "id" => plan.id,
        "changes" => plan.change_set,
        "manifest_hash" => plan.manifest_hash
      )
    end
  end

  desc "config apply PLAN_ID", "Apply a previously created plan"
  def config_apply(plan_id)
    within_org do
      plan = ConfigPlan.find(plan_id)
      ConfigApplier.apply!(plan)
      puts "applied #{plan.id}"
    end
  rescue ConfigApplier::ObjectChanged => e
    puts "refused #{e.message}"
    exit 1
  end

  default_command :help

  no_commands do
    def within_org
      Current.organization_id = options[:org]
      yield
    ensure
      Current.reset
    end

    def load_docs(path)
      files = Dir.glob(File.join(path, "**/*.{yml,yaml}"))
      files.flat_map do |file|
        YAML.load_stream(File.read(file)).compact.map(&:deep_stringify_keys)
      end
    end
  end
end
