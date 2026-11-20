# Platform metadata, deliberately outside tenant default scopes.
class DemoSandbox < ApplicationRecord
  self.primary_key = "surface"
  # Two shared tenants: the recruiting UI, and one "tools" tenant behind MCP, API and CLI. A refresh
  # takes minutes on a small database, so four tenants cost four rebuilds for little demo value.
  SANDBOXES = %w[ui tools].freeze
  ALIASES = { "mcp" => "tools", "api" => "tools", "cli" => "tools" }.freeze
  # Surfaces a visitor can choose; each maps to exactly one sandbox.
  SURFACES = (SANDBOXES + ALIASES.keys).freeze
  LEGACY_SURFACES = ALIASES.keys.freeze
  validates :surface, inclusion: { in: SANDBOXES }

  def self.sandbox_for(surface) = ALIASES.fetch(surface.to_s, surface.to_s)

  def self.for_organization(id)
    return nil if id.blank? || !table_exists?
    find_by(organization_id: id)
  end

  def slug = "big-buck-lab-#{surface}"

  def snapshot
    { surface: surface, organization_id: organization_id, generation: generation,
      state: state, seeded_at: seeded_at, resets_at: resets_at, shared: true }
  end
end
