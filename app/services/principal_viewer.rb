# frozen_string_literal: true

# Adapts a Principal to the membership-shaped viewer PersonVisibility expects,
# so agent and personal-token scopes limit what people a caller can see.
class PrincipalViewer
  attr_reader :principal

  def initialize(principal)
    @principal = principal
  end

  def permission?(name)
    principal.can?(name)
  end

  def org_wide?
    principal.org_wide?
  end

  # The person behind the credential, for rules tied to being assigned work (interview panels).
  # An agent acting for someone does not inherit those assignments.
  def interviewer_user_id
    principal.agent ? nil : principal.user_id
  end

  def membership_scopes
    principal.membership ? principal.membership.membership_scopes : MembershipScope.none
  end
end
