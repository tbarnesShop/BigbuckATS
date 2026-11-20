# Shared lab tenants. Named MySQL locks serialize reset and live requests across workers.
class DemoWorkspaces
  Error = Class.new(StandardError) do
    attr_reader :code
    def initialize(code, message)
      @code = code
      super(message)
    end
  end
  # How long a lab sandbox lives before the next request (or ResetDemoSandboxesJob) refreshes it.
  # Development defaults to a day. Production on GCP sets BIGBUCK_DEMO_RESET_AT=03:00 (America/New_York)
  # instead: every refresh — manual or scheduled — aims at the next 3am ET, so a daytime reseed does
  # not push the nightly window out. Cloud Scheduler still FORCE-runs demo:prepare at that wall clock;
  # resets_at is the safety net and the session/credential expiry.
  INTERVAL = ENV.fetch("BIGBUCK_DEMO_INTERVAL_HOURS", Rails.env.development? ? "24" : "1").to_f.hours

  def self.enabled!
    raise Error.new("demo_disabled", "The interactive lab is disabled on this deployment.") unless Rails.configuration.x.demo_sign_in
  end

  def self.lock_name(surface) = "bigbuck-demo-#{ActiveRecord::Base.connection_db_config.database}-#{surface}"

  # How long FORCE / scheduler prepares wait for an in-flight refresh (template copy can take minutes).
  FORCE_LOCK_WAIT = 900
  # Expired sandboxes: wait briefly so concurrent sign-ins queue behind one refresh instead of all
  # returning sandbox_busy while the winner copies tens of thousands of rows.
  REFRESH_LOCK_WAIT = 120

  def self.lock(surface, timeout: 0)
    raise Error.new("invalid_surface", "Choose UI, MCP, API or CLI.") unless DemoSandbox::SURFACES.include?(surface)
    surface = DemoSandbox.sandbox_for(surface)
    ActiveRecord::Base.connection_pool.with_connection do |conn|
      name = conn.quote(lock_name(surface))
      acquired = conn.uncached { conn.select_value("SELECT GET_LOCK(#{name}, #{timeout.to_i})") }.to_i == 1
      raise Error.new("sandbox_busy", "This shared workspace is busy or refreshing. Try again shortly.") unless acquired
      begin
        yield
      ensure
        conn.uncached { conn.select_value("SELECT RELEASE_LOCK(#{name})") }
      end
    end
  end

  def self.prepare!(surface, force: false)
    enabled!
    raise Error.new("invalid_surface", "Choose UI, MCP, API or CLI.") unless DemoSandbox::SURFACES.include?(surface)
    # A ready sandbox needs no lock: taking it (with no wait) made concurrent sign-ins fail as busy.
    unless force
      ready = DemoSandbox.find_by(surface: DemoSandbox.sandbox_for(surface))
      return ready if ready&.state == "ready" && ready.resets_at.present? && ready.resets_at > Time.current
    end
    # Zero-wait here raced the 3am scheduler against ResetDemoSandboxesJob / the first visitor and left
    # expired sandboxes failing every subsequent status call as busy.
    lock(surface, timeout: force ? FORCE_LOCK_WAIT : REFRESH_LOCK_WAIT) do
      sandbox = DemoSandbox.find_or_create_by!(surface: DemoSandbox.sandbox_for(surface))
      refresh!(sandbox) if force || sandbox.state != "ready" || !sandbox.resets_at || sandbox.resets_at <= Time.current
      sandbox.reload
    end
  end

  # Local demos get the full enriched dataset (jobs, resumes, interviews, offers, sequences, ...).
  # Tests and production keep the small deterministic BigBuckDataset unless BIGBUCK_DEMO_ENRICH=1.
  def self.seeder
    enrich = ENV.fetch("BIGBUCK_DEMO_ENRICH", Rails.env.development? ? "1" : "0") == "1"
    enrich ? BigBuckDemoSeed : BigBuckDataset
  end

  # Copies the shared template tenant (DemoTemplate), building it first if the seed code changed.
  # BIGBUCK_DEMO_TEMPLATE=0 runs the seeder for every sandbox instead.
  def self.refresh!(sandbox)
    template = DemoTemplate.ensure! if DemoTemplate.enabled?
    if sandbox.organization_id
      begin
        AuditPurge.ensure_access!
      rescue AuditPurge::MaintenanceRequired
        raise Error.new("maintenance_required", "This workspace is waiting for the maintenance worker to refresh it.")
      end
    end
    sandbox.update!(state: "resetting")
    old_org = sandbox.organization_id
    conn = ActiveRecord::Base.connection
    begin
      # Only registered lab tenants can be purged. Includes later-added tenant tables.
      ActiveRecord::Base.transaction do
        wipe_organization!(conn, old_org) if old_org
        organization = if template
          org, stats = DemoTemplate.copy_into(slug: sandbox.slug, meta: template)
          Rails.logger.info({ event: "demo.sandbox_copied", surface: sandbox.surface, **stats.to_h }.to_json)
          org
        else
          Current.set(organization_id: nil, principal: nil, actor_type: "system", source_surface: "system") do
            seeder.call(slug: sandbox.slug)
          end.organization
        end
        # The seed hires some candidates without walking the offer path, so it turns this rule off
        # while it runs. Visitors get the real rule: Mark hired waits for an accepted offer.
        organization.reload.merge_settings!("hire_requires_accepted_offer" => true)
        sandbox.update!(organization_id: organization.id, state: "ready",
          generation: sandbox.seeded_at ? sandbox.generation + 1 : sandbox.generation,
          seeded_at: Time.current, resets_at: next_resets_at)
      end
    rescue StandardError
      sandbox.update!(state: "failed")
      raise
    ensure
      conn.execute("SET FOREIGN_KEY_CHECKS=1")
      conn.execute("SET @bigbuck_audit_purge=NULL")
    end
  end

  # Next deadline after `now`. BIGBUCK_DEMO_RESET_AT (HH:MM) + BIGBUCK_DEMO_RESET_TZ win when set so
  # a manual FORCE refresh still lands on tonight/tomorrow's fixed wall clock. Otherwise INTERVAL.
  def self.next_resets_at(now: Time.current)
    at = ENV["BIGBUCK_DEMO_RESET_AT"].to_s.strip
    return now + INTERVAL if at.empty?

    hour, minute = at.split(":", 2).map { |part| Integer(part, 10) }
    raise ArgumentError, "BIGBUCK_DEMO_RESET_AT must be HH:MM" unless hour && minute && (0..23).cover?(hour) && (0..59).cover?(minute)

    tz_name = ENV.fetch("BIGBUCK_DEMO_RESET_TZ", "America/New_York")
    tz = ActiveSupport::TimeZone[tz_name] or raise ArgumentError, "Unknown BIGBUCK_DEMO_RESET_TZ #{tz_name}"
    local = now.in_time_zone(tz)
    candidate = local.change(hour: hour, min: minute, sec: 0)
    candidate += 1.day if candidate <= local
    candidate
  end

  # Removes one lab tenant. Active Storage rows carry no organization_id, so the table sweep would
  # orphan resume files. Sandboxes share files with the template snapshot, so a file is purged
  # (blob + file) only once no other tenant is attached to it and the snapshot no longer lists it.
  def self.wipe_organization!(conn, org_id)
    rows = DemoTemplate.attachment_rows(conn, org_id)
    if rows.any?
      blob_ids = rows.map { |row| row[4].to_i }.uniq - DemoTemplate.protected_blob_ids
      ActiveStorage::Attachment.where(id: rows.map(&:first)).delete_all
      ActiveStorage::Blob.where(id: blob_ids).where.not(id: ActiveStorage::Attachment.select(:blob_id)).find_each(&:purge)
    end
    conn.execute("SET FOREIGN_KEY_CHECKS=0")
    conn.execute("SET @bigbuck_audit_purge=1")
    conn.tables.each do |table|
      next if table == "demo_sandboxes"
      next unless conn.columns(table).any? { |column| column.name == "organization_id" }
      conn.execute("DELETE FROM #{conn.quote_table_name(table)} WHERE organization_id=#{conn.quote(org_id)}")
    end
    conn.execute("DELETE FROM organizations WHERE id=#{conn.quote(org_id)}")
  end

  # The old per-surface sandboxes (mcp, api, cli) are folded into "tools". Drop their rows and tenants.
  # wipe_organization! leaves the foreign-key and audit-purge session flags set; reset them here.
  def self.retire_legacy!
    AuditPurge.ensure_access!
    conn = ActiveRecord::Base.connection
    DemoSandbox.unscoped.where(surface: DemoSandbox::LEGACY_SURFACES).find_each do |legacy|
      ActiveRecord::Base.transaction do
        wipe_organization!(conn, legacy.organization_id) if legacy.organization_id
        legacy.delete # no audit callback: the tenant it would audit is gone
      end
    end
  ensure
    conn&.execute("SET FOREIGN_KEY_CHECKS=1")
    conn&.execute("SET @bigbuck_audit_purge=NULL")
  end

  def self.session!(surface:, email:, generation: nil)
    sandbox = prepare!(surface)
    lock(surface, timeout: 2) do
      sandbox.reload
      if generation.present? && generation.to_i != sandbox.generation
        raise Error.new("sandbox_expired", "The shared demo has refreshed. Choose a persona to start again.")
      end
      Current.set(organization_id: sandbox.organization_id, actor_type: "user", source_surface: "web") do
        member = Membership.includes(:user, :role).find_by!(user: User.find_by!(email: email), status: "active")
        user = member.user
        Current.actor_id = user.id
        browser = CredentialIssuer.call(kind: "session", name: "Lab #{surface}", user: user,
          expires_at: sandbox.resets_at, created_by: user)
        personal = CredentialIssuer.call(kind: "personal", name: "Lab tools", user: user, scopes: Scopes::ALL,
          expires_at: sandbox.resets_at, created_by: user)
        agent = Agent.find_or_initialize_by(owner_membership: member, name: "#{user.name}'s lab agent")
        # Only scopes this persona's role backs, so the agent matches what the Agents page lets them grant.
        agent.scopes = Scopes.grantable_for(member.role.permissions) -
          %w[people:erase people:merge roles:write agents:write credentials:manage]
        agent.save!
        agent_credential = CredentialIssuer.call(kind: "agent", name: "Lab MCP", agent: agent,
          expires_at: sandbox.resets_at, created_by: user)
        {
          sandbox: sandbox.snapshot, organization: { id: sandbox.organization_id, slug: sandbox.slug },
          user: { id: user.id, email: user.email, name: user.name }, role_key: member.role.key,
          permissions: member.role.permissions,
          session: { token: browser.token, expires_at: sandbox.resets_at },
          tools: { token: personal.token, agent_token: agent_credential.token, agent_id: agent.id }
        }
      end
    end
  end
end
