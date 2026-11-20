# frozen_string_literal: true

# Connect a user or domain calendar. A calendar id that names a domain must
# be on a verified domain. Without a real grant the row stays pending.
# `sm://demo` is not a grant.
class CalendarConnector
  KINDS = %w[user domain].freeze

  def self.connect!(calendar_id:, kind: nil, user_id: nil, secret_ref: nil, actor_id: Current.actor_id,
                    allow_domain: false, allow_other_user: false)
    kind = kind.presence || "user"
    raise ArgumentError, "unknown_kind:#{kind}" unless KINDS.include?(kind)
    raise Authorization::InsufficientPermission, "settings.manage" if kind == "domain" && !allow_domain

    calendar_id = calendar_id.to_s.strip
    raise ArgumentError, "calendar_id_required" if calendar_id.blank?

    domain = domain_of(calendar_id)
    GoogleSignIn.allow?(email: "calendar@#{domain}") if domain.present?

    owner_id = kind == "domain" ? nil : user_id.presence || actor_id
    if kind == "user" && owner_id.present? && actor_id.present? && owner_id != actor_id && !allow_other_user
      raise Authorization::InsufficientPermission, "settings.manage"
    end

    secret = secret_ref.presence
    granted = secret.present? && secret != "sm://demo"
    connection = CalendarConnection.new(
      kind: kind,
      user_id: owner_id,
      calendar_id: calendar_id,
      secret_ref: secret || "sm://pending",
      status: granted ? "connected" : "pending"
    )
    ChangeWriter.call(
      record: connection,
      action: "calendar_connection.created",
      event_type: "calendar_connection.created",
      payload: { "kind" => connection.kind, "calendar_id" => connection.calendar_id, "status" => connection.status }
    )
    connection
  end

  # Email calendars use the part after @. Domain-wide ids use the `domain:` prefix.
  def self.domain_of(calendar_id)
    if calendar_id.include?("@")
      calendar_id.split("@", 2).last.downcase.presence
    elsif calendar_id.downcase.start_with?("domain:")
      calendar_id.split(":", 2).last.downcase.presence
    end
  end
end
