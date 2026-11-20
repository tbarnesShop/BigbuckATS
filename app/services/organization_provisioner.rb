# frozen_string_literal: true

class OrganizationProvisioner
  def self.call(name:, slug:, owner_email:, owner_name:)
    new(name: name, slug: slug, owner_email: owner_email, owner_name: owner_name).call
  end

  def initialize(name:, slug:, owner_email:, owner_name:)
    @name = name
    @slug = slug
    @owner_email = owner_email
    @owner_name = owner_name
  end

  # Every org starts with one working outreach sequence, so the first enrollment needs no setup.
  def seed_outreach_defaults!
    MessageTemplate.create!(
      key: "starter-intro", message_type: "sequence", locale: "en",
      subject: "Quick question, {{person.display_name}}",
      body: "Hi {{person.display_name}},\n\nWe have a role that looks like a fit for your background. " \
            "Open to a short conversation this week?\n\nThanks"
    )
    MessageTemplate.create!(
      key: "starter-follow-up", message_type: "sequence", locale: "en",
      subject: "Following up, {{person.display_name}}",
      body: "Hi {{person.display_name}},\n\nJust floating this back to the top of your inbox in case it got buried. " \
            "Happy to share details if useful.\n\nThanks"
    )
    Sequence.create!(
      key: "starter-outreach", name: "Starter outreach", status: "active", shared: true, is_template: true,
      steps: [
        { "type" => "email", "template_key" => "starter-intro" },
        { "type" => "wait", "days" => 3 },
        { "type" => "email", "template_key" => "starter-follow-up" }
      ]
    )
  end

  def call
    ActiveRecord::Base.transaction do
      org = Organization.create!(name: @name, slug: @slug)
      Current.organization_id = org.id

      roles = Permissions::PRESETS.to_h do |key, perms|
        role = Role.create!(key: key, name: key.humanize, system: true) # "hiring_manager" → "Hiring manager"
        role.grant!(*perms)
        [ key, role ]
      end

      user = User.find_or_create_by!(email: @owner_email) { |u| u.name = @owner_name }
      membership = Membership.create!(user: user, role: roles["owner"], status: "active")

      department = Dimension.create!(
        key: "department", label: "Department", hierarchical: true, system: true,
        applies_to: %w[job requisition user]
      )
      location = Dimension.create!(
        key: "location", label: "Location", hierarchical: true, system: true,
        applies_to: %w[job person user]
      )

      seed_outreach_defaults!

      {
        organization: org,
        user: user,
        membership: membership,
        roles: roles,
        dimensions: { department: department, location: location }
      }
    end
  end
end
