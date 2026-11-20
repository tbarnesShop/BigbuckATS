# frozen_string_literal: true

# Apply is refused only if an object in the plan changed since plan time (per-object concurrency).
class ConfigApplier
  class ObjectChanged < StandardError
    attr_reader :identity

    def initialize(identity)
      @identity = identity
      super("config_object_changed:#{identity}")
    end
  end

  def self.apply!(plan)
    new(plan).apply!
  end

  def initialize(plan)
    @plan = plan
  end

  def apply!
    raise ArgumentError, "plan not open" unless @plan.status == "open"
    if DemoSandbox.for_organization(Current.organization_id) && @plan.change_set.any? { |change| DemoPolicy.blocked?(action: change["op"], values: change) }
      raise Authenticator::Forbidden.new("demo_action_blocked", DemoPolicy::MESSAGE)
    end

    ActiveRecord::Base.transaction do
      @plan.object_versions.each do |identity, expected_version|
        kind, key = identity.split("/", 2)
        obj = ConfigObject.find_by!(kind: kind, key: key)
        raise ObjectChanged, identity if obj.version != expected_version
      end

      @plan.change_set.each { |change| apply_change(change.stringify_keys) }

      number = (ConfigRevision.maximum(:number) || 0) + 1
      ConfigRevision.create!(
        number: number,
        source: "apply",
        actor_id: Current.actor_id,
        manifest_hash: @plan.manifest_hash,
        manifest: @plan.desired_manifest
      )

      @plan.update!(status: "applied")
      @plan
    end
  rescue ObjectChanged, ConfigExecutors::Invalid => e
    @plan.update!(status: "refused", refuse_reason: e.message)
    raise
  end

  private

  def apply_change(change)
    store_change(change)
    ConfigExecutors.apply!(change["op"], change["kind"], change["key"], change["to_spec"] || {})
  end

  def store_change(change)
    case change["op"]
    when "create"
      ConfigObject.create!(kind: change["kind"], key: change["key"], spec: change["to_spec"], version: 1)
    when "update"
      obj = ConfigObject.find_by!(kind: change["kind"], key: change["key"])
      obj.update!(spec: change["to_spec"], version: obj.version + 1)
    when "archive"
      obj = ConfigObject.find_by!(kind: change["kind"], key: change["key"])
      obj.update!(status: "archived", version: obj.version + 1)
    else
      raise ArgumentError, "unknown op #{change['op']}"
    end
  end
end
