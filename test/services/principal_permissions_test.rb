# frozen_string_literal: true

require "test_helper"

class PrincipalPermissionsTest < ActiveSupport::TestCase
  setup do
    data = OrganizationProvisioner.call(name: "Owner permissions", slug: "owner-perms-#{SecureRandom.hex(4)}",
      owner_email: "owner-perms-#{SecureRandom.hex(4)}@example.test", owner_name: "Owner")
    @org = data[:organization]
    Current.organization_id = @org.id
    @owner = data[:user]
    @membership = data[:membership]
  end

  teardown { Current.reset }

  test "only a human owner receives person erasure even when other roles grant it" do
    assert principal.can?("person.erase")
    role = Role.create!(key: "custom-admin", name: "Custom admin")
    role.grant!("person.read", "person.erase")
    @membership.update!(role: role)
    refute principal.can?("person.erase")
    assert principal.can?("person.read")
    refute_includes principal.as_json.fetch("permissions"), "person.erase"
  end

  test "agents and integrations cannot inherit owner erasure" do
    refute principal(agent: Object.new).can?("person.erase")
    refute principal(user: nil).can?("person.erase")
  end

  private

  def principal(agent: nil, user: @owner)
    Principal.new(organization_id: @org.id, credential: nil, user: user, membership: @membership,
      agent: agent, permissions: %w[person.read person.erase], api_version: "2026-01-01")
  end
end
