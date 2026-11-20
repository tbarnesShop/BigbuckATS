/**
 * Every scope Rails accepts for an agent or personal token (Scopes::MAP in app/services/scopes.rb),
 * grouped for the picker, with the role permissions each one unlocks. Effective access is always
 * scopes ∩ the owner's role, so the picker only offers scopes the signed-in member's role backs.
 * scopes.test.ts keeps this list in step with Rails.
 */
export type ScopeOption = { key: string; label: string; needs: readonly string[] }

export const SCOPE_GROUPS: ReadonlyArray<{ label: string; scopes: ReadonlyArray<ScopeOption> }> = [
  {
    label: 'People',
    scopes: [
      { key: 'people:read', label: 'Read people', needs: ['person.read'] },
      { key: 'people:write', label: 'Create and edit people', needs: ['person.create', 'person.update'] },
      { key: 'people:read_restricted', label: 'Read restricted people', needs: ['person.read_restricted'] },
      { key: 'people:merge', label: 'Merge duplicate people', needs: ['person.merge'] },
      { key: 'people:export', label: 'Export people', needs: ['person.export'] },
      { key: 'people:erase', label: 'Erase people', needs: ['person.erase'] },
      { key: 'companies:write', label: 'Manage companies', needs: ['company.manage'] },
      { key: 'documents:read', label: 'Read resumes and documents', needs: ['document.read'] },
      { key: 'documents:write', label: 'Upload documents', needs: ['document.upload'] },
    ],
  },
  {
    label: 'Hiring',
    scopes: [
      { key: 'jobs:read', label: 'Read jobs and applications', needs: ['job.read'] },
      { key: 'jobs:write', label: 'Manage jobs', needs: ['job.manage'] },
      {
        key: 'confidential:read',
        label: 'Read confidential jobs and pools',
        needs: ['job.read_confidential'],
      },
      { key: 'applications:write', label: 'Create applications', needs: ['application.create'] },
      {
        key: 'applications:transition',
        label: 'Move and archive applications',
        needs: ['application.move_stage'],
      },
      { key: 'scorecards:write', label: 'Write scorecards', needs: ['scorecard.write'] },
      { key: 'scorecards:read', label: 'Read every scorecard', needs: ['scorecard.read_all'] },
      {
        key: 'scorecards:manage',
        label: "Correct anyone's scorecard",
        needs: ['scorecard.manage'],
      },
      { key: 'scheduling:write', label: 'Schedule interviews', needs: ['interview.schedule'] },
    ],
  },
  {
    label: 'Sourcing and outreach',
    scopes: [
      { key: 'projects:read', label: 'Read pools', needs: ['project.read'] },
      { key: 'projects:write', label: 'Manage pools', needs: ['project.manage'] },
      { key: 'sequences:read', label: 'Read sequences', needs: ['sequence.read'] },
      { key: 'sequences:write', label: 'Manage sequences', needs: ['sequence.manage'] },
      { key: 'sequences:enroll', label: 'Enroll in sequences', needs: ['sequence.enroll'] },
      { key: 'communications:send', label: 'Send email', needs: ['communication.send'] },
      { key: 'mailboxes:read', label: 'Read mailboxes', needs: ['mailbox.read'] },
      { key: 'mailboxes:write', label: 'Connect and manage mailboxes', needs: ['mailbox.manage'] },
    ],
  },
  {
    label: 'Offers',
    scopes: [
      { key: 'offers:read', label: 'Read offers', needs: ['offer.read'] },
      { key: 'offers:write', label: 'Draft and send offers', needs: ['offer.create'] },
      { key: 'offers:approve', label: 'Approve offers', needs: ['offer.approve'] },
      { key: 'offers:compensation', label: 'See offer compensation', needs: ['offer.view_compensation'] },
    ],
  },
  {
    label: 'Workspace',
    scopes: [
      { key: 'webhooks:write', label: 'Manage webhooks', needs: ['webhook.manage'] },
      { key: 'events:read', label: 'Read the audit log', needs: ['audit.read'] },
      { key: 'analytics:read', label: 'Read analytics', needs: ['analytics.read'] },
      { key: 'imports:write', label: 'Import people', needs: ['import.manage'] },
      { key: 'config:plan', label: 'Plan configuration changes', needs: ['config.plan'] },
      { key: 'config:apply', label: 'Apply configuration changes', needs: ['config.apply'] },
      { key: 'settings:write', label: 'Change workspace settings', needs: ['settings.manage'] },
      { key: 'compliance:write', label: 'Manage compliance', needs: ['compliance.manage'] },
      { key: 'structure:write', label: 'Manage departments and custom fields', needs: ['dimension.manage'] },
      { key: 'roles:write', label: 'Manage roles', needs: ['role.manage'] },
      { key: 'agents:write', label: 'Manage your agents', needs: ['agent.manage_own'] },
      { key: 'credentials:manage', label: 'Manage integration credentials', needs: ['integration.manage'] },
    ],
  },
]

export const ALL_SCOPE_KEYS = SCOPE_GROUPS.flatMap((g) => g.scopes.map((s) => s.key))

/** Scopes this member can usefully grant: their role must hold what the scope unlocks. */
export function grantableScopes(permissions: readonly string[] | null | undefined) {
  return SCOPE_GROUPS.map((group) => ({
    label: group.label,
    scopes: group.scopes.filter(
      (scope) => !permissions || scope.needs.every((need) => permissions.includes(need)),
    ),
  })).filter((group) => group.scopes.length > 0)
}

export function scopeLabel(key: string): string {
  return SCOPE_GROUPS.flatMap((group) => group.scopes).find((scope) => scope.key === key)?.label ?? key
}
