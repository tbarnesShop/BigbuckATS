# frozen_string_literal: true

# Diff desired files against live config objects (kinds present in the folder only).
class ConfigPlanner
  Conflict = Class.new(StandardError)

  def self.plan(documents:)
    new(documents: documents).plan
  end

  def initialize(documents:)
    @compiled = ConfigCompiler.compile(documents)
  end

  def plan
    desired = @compiled[:items].index_by { |i| "#{i['kind']}/#{i['key']}" }
    kinds = desired.values.map { |i| i["kind"] }.uniq
    live = ConfigObject.where(kind: kinds, status: "active").index_by(&:identity)

    changes = []
    object_versions = {}

    desired.each do |identity, item|
      ConfigExecutors.validate!(item["kind"], item["key"], item["spec"])
      existing = live[identity]
      if existing.nil?
        changes << with_impact({ "kind" => item["kind"], "key" => item["key"], "op" => "create", "to_spec" => item["spec"] })
      elsif CanonicalJson.dump(existing.spec) != CanonicalJson.dump(item["spec"])
        object_versions[identity] = existing.version
        changes << with_impact({
          "kind" => item["kind"], "key" => item["key"], "op" => "update",
          "from_version" => existing.version, "to_spec" => item["spec"]
        })
      end
    end

    live.each do |identity, obj|
      next if desired.key?(identity)

      object_versions[identity] = obj.version
      changes << { "kind" => obj.kind, "key" => obj.key, "op" => "archive", "from_version" => obj.version }
    end

    ConfigPlan.create!(
      status: "open",
      desired_manifest: @compiled[:manifest],
      change_set: changes,
      object_versions: object_versions.presence || {},
      manifest_hash: @compiled[:hash]
    )
  end

  private

  # What applying this change would do beyond storing the spec (e.g. how many
  # custom field values a type change converts or cannot convert).
  def with_impact(change)
    impact = ConfigExecutors.preview(change["kind"], change["key"], change["to_spec"])
    change["executes"] = ConfigExecutors.for(change["kind"]).present?
    change["impact"] = impact if impact
    change
  end
end
