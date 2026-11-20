# frozen_string_literal: true

# UI/API edits also create a revision and bump the object version (one history).
class ConfigUiEdit
  def self.upsert!(kind:, key:, spec:)
    ActiveRecord::Base.transaction { write!(kind: kind, key: key, spec: spec) }
  end

  def self.write!(kind:, key:, spec:)
    obj = ConfigObject.find_or_initialize_by(kind: kind, key: key)
    obj.spec = spec
    obj.version = obj.persisted? ? obj.version + 1 : 1
    obj.status = "active"
    ConfigExecutors.validate!(kind, key, spec)
    obj.save!
    ConfigExecutors.apply!("update", kind, key, spec)

    number = (ConfigRevision.maximum(:number) || 0) + 1
    compiled = ConfigCompiler.compile([ { "kind" => kind, "key" => key, "spec" => spec } ])
    ConfigRevision.create!(
      number: number,
      source: "ui",
      actor_id: Current.actor_id,
      manifest_hash: compiled[:hash],
      manifest: compiled[:manifest]
    )
    obj
  end
end
