# frozen_string_literal: true

# When repository_lock is on, config writes need an open break-glass session
# (or an apply credential — modeled here as actor_type "Repository").
class RepositoryLock
  Error = Class.new(StandardError)
  Locked = Class.new(Error)

  def self.ensure_writable!(kind: "config", actor_type: Current.actor_type)
    org = Organization.find(Current.organization_id)
    return true unless org.repository_lock
    return true if actor_type.to_s == "Repository"
    return true if BreakGlassSession.where(status: "open").any?(&:open?)

    raise Locked, "repository_locked:#{kind}"
  end

  def self.open_break_glass!(reason:, for_duration: 1.hour, kinds: nil, actor_id: Current.actor_id)
    session = BreakGlassSession.create!(
      opened_by_user_id: actor_id,
      reason: reason,
      kinds: kinds,
      opens_at: Time.current,
      expires_at: for_duration.from_now,
      status: "open"
    )
    ChangeWriter.call(
      record: session,
      action: "config.break_glass_opened",
      event_type: "config.break_glass_opened",
      payload: { "reason" => reason, "expires_at" => session.expires_at },
      changes: { "status" => [ nil, "open" ] }
    )
    session
  end
end
