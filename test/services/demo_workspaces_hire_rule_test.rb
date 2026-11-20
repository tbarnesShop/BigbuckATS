require "test_helper"

# The lab seed hires some candidates without an accepted offer, so it turns the rule off while it
# runs. A refreshed sandbox must hand visitors the real rule back.
class DemoWorkspacesHireRuleTest < ActiveSupport::TestCase
  FakeResult = Struct.new(:organization)

  teardown { Current.reset }

  test "refresh restores hire_requires_accepted_offer after seeding" do
    seeded = lambda do
      provisioned = OrganizationProvisioner.call(name: "Lab", slug: "lab-hire-#{SecureRandom.hex(4)}",
        owner_email: "lab-#{SecureRandom.hex(4)}@example.test", owner_name: "Lab Owner")
      provisioned[:organization].merge_settings!("hire_requires_accepted_offer" => false)
      FakeResult.new(provisioned[:organization])
    end
    DemoSandbox.where(surface: "ui").delete_all
    sandbox = DemoSandbox.create!(surface: "ui", state: "failed")

    original = DemoWorkspaces.method(:seeder)
    fake = Object.new
    fake.define_singleton_method(:call) { |**| seeded.call }
    DemoWorkspaces.define_singleton_method(:seeder) { fake }
    begin
      DemoWorkspaces.refresh!(sandbox)
    ensure
      DemoWorkspaces.define_singleton_method(:seeder, original)
    end

    org = Organization.find(sandbox.reload.organization_id)
    assert_predicate org, :hire_requires_accepted_offer?
  end
end
