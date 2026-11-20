# frozen_string_literal: true

require "test_helper"

# M9e: custom fields change without breaking stored data.
class CustomFieldsTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "Field Co", slug: "field-#{SecureRandom.hex(4)}",
      owner_email: "owner-#{SecureRandom.hex(4)}@field.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id
    Current.actor_type = "user"
    @person = Person.create!(display_name: "Ada")
    @other = Person.create!(display_name: "Grace")
  end

  teardown { Current.reset }

  test "creating a field records version 1 and values remember their definition version" do
    field = CustomFieldDefinitions.create!(entity: "person", key: "years", label: "Years", field_type: "number")
    assert_equal 1, field.version
    assert_equal [ "created" ], field.versions.map(&:change_kind)

    value = CustomFieldValues.write!(entity_type: "Person", entity_id: @person.id, key: "years", value: "7")
    assert_equal 7, value.typed_value
    assert_equal 1, value.field_version
    assert_equal 1, value.version
  end

  test "values are validated against the definition" do
    CustomFieldDefinitions.create!(entity: "person", key: "level", label: "Level", field_type: "select",
                                   options: %w[junior senior])
    error = assert_raises(CustomFieldDefinitions::Error) do
      CustomFieldValues.write!(entity_type: "Person", entity_id: @person.id, key: "level", value: "principal")
    end
    assert_equal "invalid_value", error.code
    assert_equal "senior", CustomFieldValues.write!(entity_type: "Person", entity_id: @person.id, key: "level", value: "senior").typed_value
  end

  test "archiving keeps values and blocks new writes; restoring brings them back" do
    field = CustomFieldDefinitions.create!(entity: "person", key: "source", label: "Source", field_type: "text")
    CustomFieldValues.write!(entity_type: "Person", entity_id: @person.id, key: "source", value: "referral")

    CustomFieldDefinitions.archive!(field)
    assert_equal 1, CustomFieldValue.where(custom_field_id: field.id).count
    error = assert_raises(CustomFieldDefinitions::Error) do
      CustomFieldValues.write!(entity_type: "Person", entity_id: @person.id, key: "source", value: "x")
    end
    assert_equal "field_archived", error.code
    assert_raises(ActiveRecord::DeleteRestrictionError) { field.reload.destroy }

    CustomFieldDefinitions.restore!(field)
    assert_equal "referral", CustomFieldValues.for_entities(entity_type: "Person", entity_ids: [ @person.id ])[@person.id].first.typed_value
    assert_equal %w[created archived restored], field.reload.versions.map(&:change_kind)
  end

  test "a type change converts values, and refuses when some cannot convert" do
    field = CustomFieldDefinitions.create!(entity: "person", key: "years", label: "Years", field_type: "text")
    CustomFieldValues.write!(entity_type: "Person", entity_id: @person.id, key: "years", value: "12")
    CustomFieldValues.write!(entity_type: "Person", entity_id: @other.id, key: "years", value: "about ten")

    preview = CustomFieldDefinitions.preview_type_change(field, to_type: "number")
    assert_equal({ "total" => 2, "convertible" => 1, "unconvertible" => 1 }, preview.slice("total", "convertible", "unconvertible"))

    error = assert_raises(CustomFieldDefinitions::Error) { CustomFieldDefinitions.change_type!(field, to_type: "number") }
    assert_equal "unconvertible_values", error.code
    assert_equal "text", field.reload.field_type, "refuse changes nothing"

    changed = CustomFieldDefinitions.change_type!(field, to_type: "number", on_unconvertible: "clear")
    assert_equal "number", changed.field_type
    assert_equal 2, changed.version
    values = CustomFieldValue.where(custom_field_id: field.id).index_by(&:entity_id)
    assert_equal 12, values[@person.id].typed_value
    assert_equal 2, values[@person.id].field_version
    assert_nil values[@other.id].typed_value
    summary = changed.versions.last.migration_summary
    assert_equal [ values[@other.id].id ], summary["cleared_value_ids"]
  end

  test "an option still in use cannot be removed" do
    field = CustomFieldDefinitions.create!(entity: "person", key: "level", label: "Level", field_type: "select",
                                           options: %w[junior senior])
    CustomFieldValues.write!(entity_type: "Person", entity_id: @person.id, key: "level", value: "junior")

    error = assert_raises(CustomFieldDefinitions::Error) { CustomFieldDefinitions.update!(field, { "options" => %w[senior] }) }
    assert_equal "option_in_use", error.code

    updated = CustomFieldDefinitions.update!(field, { "options" => %w[junior senior staff] }, expected_version: 1)
    assert_equal %w[junior senior staff], updated.option_keys
    stale = assert_raises(CustomFieldDefinitions::Error) { CustomFieldDefinitions.update!(field, { "label" => "x" }, expected_version: 1) }
    assert_equal "stale_version", stale.code
  end

  test "field_type cannot be changed by a plain update" do
    field = CustomFieldDefinitions.create!(entity: "person", key: "years", label: "Years", field_type: "number")
    error = assert_raises(CustomFieldDefinitions::Error) { CustomFieldDefinitions.update!(field, { "field_type" => "text" }) }
    assert_equal "not_editable", error.code
  end

  test "config-as-code creates real fields and runs type changes through the same migration" do
    doc = { "kind" => "CustomField", "key" => "person.region_code", "spec" => { "type" => "text", "label" => "Region" } }
    ConfigApplier.apply!(ConfigPlanner.plan(documents: [ doc ]))
    field = CustomField.find_by!(entity: "person", key: "region_code")
    assert_equal "text", field.field_type

    CustomFieldValues.write!(entity_type: "Person", entity_id: @person.id, key: "region_code", value: "42")
    CustomFieldValues.write!(entity_type: "Person", entity_id: @other.id, key: "region_code", value: "north")
    plan = ConfigPlanner.plan(documents: [ doc.deep_merge("spec" => { "type" => "number" }) ])
    assert_equal 1, plan.change_set.first.dig("impact", "unconvertible")
    assert_raises(ConfigExecutors::Invalid) { ConfigApplier.apply!(plan) }
    assert_equal "refused", plan.reload.status
    assert_equal "text", field.reload.field_type

    clear = doc.deep_merge("spec" => { "type" => "number", "on_unconvertible" => "clear" })
    ConfigApplier.apply!(ConfigPlanner.plan(documents: [ clear ]))
    assert_equal "number", field.reload.field_type
  end

  test "config-as-code publishes pipeline templates" do
    doc = { "kind" => "PipelineTemplate", "key" => "sales", "spec" => {
      "name" => "Sales", "stages" => [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ]
    } }
    ConfigApplier.apply!(ConfigPlanner.plan(documents: [ doc ]))
    template = PipelineTemplate.find_by!(key: "sales")
    assert_equal 1, template.published_version
    assert_equal [ "applied" ], template.latest_stages.map { |s| s["key"] }

    renamed = doc.deep_merge("spec" => { "name" => "Sales hiring" })
    ConfigApplier.apply!(ConfigPlanner.plan(documents: [ renamed ]))
    assert_equal "Sales hiring", template.reload.name
    assert_equal 1, template.published_version, "unchanged stages do not publish a new version"
  end
end
