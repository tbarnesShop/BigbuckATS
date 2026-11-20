# frozen_string_literal: true

require "test_helper"

class CompositeTenantFkTest < ActiveSupport::TestCase
  test "contact point cannot reference a person from another organization" do
    a = OrganizationProvisioner.call(
      name: "A", slug: "a-#{SecureRandom.hex(3)}",
      owner_email: "a-#{SecureRandom.hex(3)}@t.test", owner_name: "A"
    )
    b = OrganizationProvisioner.call(
      name: "B", slug: "b-#{SecureRandom.hex(3)}",
      owner_email: "b-#{SecureRandom.hex(3)}@t.test", owner_name: "B"
    )

    Current.organization_id = a[:organization].id
    person_a = Person.create!(display_name: "In A")

    assert_raises(ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid) do
      PersonContactPoint.connection.execute(<<~SQL.squish)
        INSERT INTO person_contact_points
          (id, organization_id, person_id, kind, value, normalized_value, verified, `primary`, created_at, updated_at)
        VALUES (
          '#{Id.generate}',
          '#{b[:organization].id}',
          '#{person_a.id}',
          'email',
          'x@y.test',
          'x@y.test',
          0,
          1,
          NOW(6),
          NOW(6)
        )
      SQL
    end
  ensure
    Current.reset
  end
end
