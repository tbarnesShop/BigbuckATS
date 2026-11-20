# Public lab control plane, only enabled on demo deployments. Never accepts arbitrary tenants.
class DemoController < ActionController::API
  include ProblemResponses
  rescue_from DemoWorkspaces::Error do |error|
    render_problem(status: :service_unavailable, code: error.code, title: error.message)
  end
  rescue_from ActiveRecord::RecordNotFound do
    render_problem(status: :not_found, code: "persona_not_found", title: "Choose an existing demo persona.")
  end

  def status
    sandbox = DemoWorkspaces.prepare!(params[:surface])
    DemoWorkspaces.lock(sandbox.surface, timeout: 2) do
      Current.set(organization_id: sandbox.organization_id) do
        roles = Membership.includes(:user, :role).where(status: "active").map do |member|
          { email: member.user.email, name: member.user.name, role_key: member.role.key,
            role_name: member.role.name, permissions: member.role.permissions }
        end
        render json: { sandbox: sandbox.snapshot, roles: roles }
      end
    end
  end

  def session
    render json: DemoWorkspaces.session!(surface: params.require(:surface), email: params.require(:email), generation: params[:generation]), status: :created
  end
end
