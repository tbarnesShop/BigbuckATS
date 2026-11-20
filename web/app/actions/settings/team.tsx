import type { Handle } from 'remix/component'

import type { TeamMember, TeamRole } from '../../data/api.ts'
import { signedIn } from '../../data/auth.ts'
import { label } from '../../data/labels.ts'
import { EmptyState, Shell } from '../../ui/shell.tsx'

/** Seeded role names can be stored keys ("Hiring_manager"); show the readable label instead. */
function roleName(name: string | null | undefined, key: string | null | undefined) {
  return !name || /[_-]/.test(name) || name === name.toLowerCase() ? label(key ?? name) : name
}

/** Permission keys grouped by area: "offer.approve" → Offer · approve. */
function permissionGroups(permissions: string[]) {
  const groups = new Map<string, string[]>()
  for (const permission of permissions) {
    const [area = permission, ...rest] = permission.split('.')
    groups.set(area, [...(groups.get(area) ?? []), label(rest.join('.') || area).toLowerCase()])
  }
  return [...groups].sort(([a], [b]) => a.localeCompare(b))
}

export function TeamPage(handle: Handle<{ members: TeamMember[]; roles: TeamRole[] }>) {
  return () => {
    const { members, roles } = handle.props
    const me = signedIn()?.email
    return (
      <Shell title="Team" eyebrow="Settings">
        <div class="record-workspace">
          <section class="record-section">
            <h2>
              Members <span class="tab-count">{members.length}</span>
            </h2>
            <p class="sub">
              Everyone with access to this workspace and their organization role. Who works on a particular
              job is set on that job's Settings tab, under Hiring team.
            </p>
            {members.length === 0 ? (
              <EmptyState>No active members.</EmptyState>
            ) : (
              <div class="table-wrap" role="region" aria-label="Team members" tabIndex={0}>
                <table class="table">
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Email</th>
                      <th>Role</th>
                      <th>Sees</th>
                    </tr>
                  </thead>
                  <tbody>
                    {members.map((member) => (
                      <tr key={member.user_id}>
                        <td>
                          {member.name ?? 'Member'}
                          {member.email && member.email === me ? (
                            <span class="chip chip-info">You</span>
                          ) : null}
                        </td>
                        <td>{member.email ?? '—'}</td>
                        <td>{roleName(member.role_name, member.role_key)}</td>
                        <td>{member.scoped ? 'Their departments only' : 'Whole organization'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <p class="sub">
              Inviting people and changing organization roles is not available in the demo workspace.
            </p>
          </section>
          <section class="record-section">
            <h2>Roles</h2>
            {roles.map((role) => (
              <details key={role.key} class="plan-stage">
                <summary>
                  {roleName(role.name, role.key)} <span class="tab-count">{role.member_count} members</span>
                </summary>
                <dl class="field-list">
                  {permissionGroups(role.permissions).map(([area, actions]) => (
                    <div key={area}>
                      <dt>{label(area)}</dt>
                      <dd>{actions.join(', ')}</dd>
                    </div>
                  ))}
                </dl>
              </details>
            ))}
          </section>
        </div>
      </Shell>
    )
  }
}
