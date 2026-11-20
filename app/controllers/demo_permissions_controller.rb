# Read-only lab inspector. Credentials stay in the server-side lab session.
class DemoPermissionsController < ApplicationController
  def show
    DemoWorkspaces.enabled!
    sandbox = DemoSandbox.for_organization(Current.organization_id)
    raise Authenticator::Forbidden.new("demo_session_required", "Choose a lab persona first.") unless sandbox && current_principal.is_a?(Principal)
    principal = current_principal
    render json: principal.as_json.merge(
      "role_permissions" => principal.membership&.role&.permissions || [],
      "credential_scopes" => principal.credential&.scopes || [],
      "agent_scopes" => principal.agent&.scopes || [],
      "membership_scope" => principal.membership&.membership_scopes&.as_json(except: [ :created_at, :updated_at ]) || [],
      "sandbox" => sandbox.snapshot
    )
  end
end
