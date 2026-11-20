# frozen_string_literal: true

require "test_helper"

class ConfigPlanApplyTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "CfgCo", slug: "cfg-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@c.test", owner_name: "O"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id
  end

  teardown { Current.reset }

  def pipeline_doc(name: "Engineering hiring")
    {
      "kind" => "PipelineTemplate",
      "key" => "engineering-hiring",
      "spec" => {
        "name" => name,
        "stages" => [
          { "key" => "review", "name" => "Review", "type" => "review",
            "when" => { "op" => "eq", "left" => "person.country", "right" => "US" } }
        ]
      }
    }
  end

  test "a plan applies successfully" do
    plan = ConfigPlanner.plan(documents: [ pipeline_doc ])
    ConfigApplier.apply!(plan)
    assert plan.reload.applied?
    obj = ConfigObject.find_by!(kind: "PipelineTemplate", key: "engineering-hiring")
    assert_equal "Engineering hiring", obj.spec["name"]
    assert_equal 1, ConfigRevision.count
  end

  test "planning an already applied manifest returns an applicable no-op plan" do
    original = ConfigPlanner.plan(documents: [ pipeline_doc ])
    ConfigApplier.apply!(original)
    repeated = ConfigPlanner.plan(documents: [ pipeline_doc ])
    assert_equal [], repeated.change_set
    ConfigApplier.apply!(repeated)
    assert repeated.reload.applied?
  end

  test "conflicting UI edit to the same object blocks apply" do
    ConfigUiEdit.upsert!(kind: "PipelineTemplate", key: "engineering-hiring", spec: pipeline_doc["spec"])
    plan = ConfigPlanner.plan(documents: [ pipeline_doc(name: "Renamed from files") ])

    # UI edit bumps version after plan
    ConfigUiEdit.upsert!(
      kind: "PipelineTemplate",
      key: "engineering-hiring",
      spec: pipeline_doc(name: "Renamed in UI")["spec"]
    )

    error = assert_raises(ConfigApplier::ObjectChanged) { ConfigApplier.apply!(plan) }
    assert_equal "PipelineTemplate/engineering-hiring", error.identity
    assert_equal "refused", plan.reload.status
    assert_match(/config_object_changed/, plan.refuse_reason)
  end

  test "unrelated UI edit does not block apply" do
    ConfigUiEdit.upsert!(kind: "PipelineTemplate", key: "engineering-hiring", spec: pipeline_doc["spec"])
    plan = ConfigPlanner.plan(documents: [ pipeline_doc(name: "From files") ])

    ConfigUiEdit.upsert!(
      kind: "MessageTemplate",
      key: "offer-sent",
      spec: { "subject" => "Your offer" }
    )

    ConfigApplier.apply!(plan)
    assert plan.reload.applied?
    assert_equal "From files", ConfigObject.find_by!(key: "engineering-hiring").spec["name"]
  end
end
