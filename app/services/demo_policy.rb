# Semantic guard shared by every transport. Hiding controls is not authorization.
module DemoPolicy
  MESSAGE = "This action is blocked in shared demo workspaces to preserve sample records and identity."
  BLOCKED_KEYS = %w[erase erased_at archive archived_at delete destroy purge merge remove revoke cancel rescind reject anonymize clear stop decline release withdraw].freeze
  IDENTITY_CONTROLLERS = %w[v1/agents v1/credentials v1/organizations].freeze
  # Named exceptions to the destructive-word guard: staffing changes that delete no sample record a
  # visitor could not put back in one click. Keep this list short and explicit.
  REVERSIBLE_ACTIONS = %w[v1/jobs#remove_team_member].freeze

  def self.reversible?(controller_path, action_name)
    REVERSIBLE_ACTIONS.include?("#{controller_path}##{action_name}")
  end

  # Archiving a job application (reject or withdraw, with a reason) is an everyday hiring outcome the
  # lab should show. It keeps the person and the audited history; erasing or archiving people stays blocked.
  APPLICATION_OUTCOMES = %w[reject withdraw].freeze

  def self.application_outcome?(controller_path, action_name, params)
    return false unless controller_path == "v1/applications" && action_name == "create_transition"
    nested = params[:transition] || params["transition"] || {}
    command = (params[:command] || params["command"] || nested[:command] || nested["command"]).to_s
    return false unless APPLICATION_OUTCOMES.include?(command)
    # Nothing else in the payload may carry a blocked value.
    !inspect_values(params.to_h.except("command", "transition", "controller", "action", "id", "reason").merge(
      "transition" => nested.to_h.except("command", "reason")))
  end

  def self.blocked?(action:, values: {})
    words = action.to_s.underscore.split(/[^a-z0-9]+/)
    return true if (words & BLOCKED_KEYS).any?
    inspect_values(values)
  end

  def self.inspect_values(value)
    case value
    when Hash, ActionController::Parameters
      value.to_h.any? do |key, child|
        BLOCKED_KEYS.include?(key.to_s.underscore) ||
          %w[organization_id owner_membership_id role_id permissions scopes].include?(key.to_s.underscore) ||
          (%w[status lifecycle_stage on_unconvertible mode action operation command erase_mode].include?(key.to_s.underscore) &&
            (child.to_s.underscore.split(/[^a-z0-9]+/) & (BLOCKED_KEYS + %w[archived deleted erased rejected rescinded cancelled canceled withdrawn anonymized])).any?) || inspect_values(child)
      end
    when Array then value.any? { |item| inspect_values(item) }
    else value.respond_to?(:to_h) ? inspect_values(value.to_h) : false
    end
  end
end
