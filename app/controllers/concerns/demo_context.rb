module DemoContext
  extend ActiveSupport::Concern

  included do
    rescue_from DemoWorkspaces::Error do |error|
      status = error.code == "sandbox_expired" ? :conflict : :service_unavailable
      render_problem(status: status, code: error.code, title: error.message)
    end
  end

  private

  # Anonymous candidate writes into lab sandboxes. Off unless the deployment opts in (a private
  # deployment, where only invited people can reach the careers page and offer links): applying and
  # answering an offer. Self-scheduling stays blocked.
  CANDIDATE_WRITES = %w[apply accept decline].freeze

  def block_demo_public_write!(organization_id, action:)
    return unless DemoSandbox.for_organization(organization_id)
    return if Rails.configuration.x.demo_candidate_writes && CANDIDATE_WRITES.include?(action)

    raise Authenticator::Forbidden.new("demo_candidate_action_blocked",
      "Candidate actions (applying, answering offers, self-scheduling) are turned off in this demo workspace.")
  end

  def with_demo_context
    sandbox = DemoSandbox.for_organization(Current.organization_id)
    return yield unless sandbox
    # Only an expired or not-ready sandbox needs the exclusive lock (to refresh it once). Holding it
    # for every request serialized each sandbox: a page that loads several sections in parallel timed
    # out on the 2 s lock wait under a slow database, so sections failed at random. A refresh marks
    # the sandbox "resetting" first, so requests that arrive during one still take this locked path.
    unless sandbox.state == "ready" && sandbox.resets_at.present? && sandbox.resets_at > Time.current
      # Wait out an in-flight copy (large demos take minutes); 2s made every parallel tab report busy.
      DemoWorkspaces.lock(sandbox.surface, timeout: DemoWorkspaces::REFRESH_LOCK_WAIT) do
        sandbox.reload
        if sandbox.state != "ready" || sandbox.resets_at <= Time.current
          DemoWorkspaces.refresh!(sandbox)
          raise DemoWorkspaces::Error.new("sandbox_expired", "The demo has refreshed. Choose a persona to start again.")
        end
      end
    end
    generation = request.headers["X-Bigbuck-Demo-Generation"]
    if Current.organization_id != sandbox.organization_id || (generation.present? && generation.to_i != sandbox.generation)
      raise DemoWorkspaces::Error.new("sandbox_expired", "This tab belongs to an earlier demo. Start again.")
    end
    raise Authenticator::Forbidden.new("demo_requires_bearer", "Demo workspaces require a role-bound credential.") unless Current.credential_id
    if !request.get? && !request.head? && controller_path != "v1/sessions" && !DemoPolicy.reversible?(controller_path, action_name) &&
        !DemoPolicy.application_outcome?(controller_path, action_name, params.to_unsafe_h)
      if request.delete? || DemoPolicy::IDENTITY_CONTROLLERS.include?(controller_path) ||
          DemoPolicy.blocked?(action: action_name, values: params.to_unsafe_h.except("controller", "action"))
        raise Authenticator::Forbidden.new("demo_action_blocked", DemoPolicy::MESSAGE)
      end
    end
    response.set_header("X-Bigbuck-Demo-Generation", sandbox.generation.to_s)
    yield
  end
end
