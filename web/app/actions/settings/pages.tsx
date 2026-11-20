import type { Handle, RemixNode } from 'remix/component'
import { css } from 'remix/component'

import type { AgentRecord, CredentialRecord } from '../../data/api.ts'
import { label } from '../../data/labels.ts'
import { signedIn } from '../../data/auth.ts'
import { canSee, settingsCards } from '../../data/nav.ts'
import { grantableScopes, scopeLabel } from '../../data/scopes.ts'
import type { CustomFieldDefinitionsQuery } from '../../graphql/generated.ts'
import { routes } from '../../routes.ts'
import { EmptyState, Field, Mute, PrimaryButton, Shell } from '../../ui/shell.tsx'
import { color, font } from '../../ui/tokens.ts'

type FieldDef = CustomFieldDefinitionsQuery['customFieldDefinitions'][number]

export const FIELD_ENTITIES = ['person', 'job', 'application'] as const
export const FIELD_TYPES = [
  'text',
  'long_text',
  'number',
  'currency',
  'date',
  'boolean',
  'select',
  'multi_select',
  'email',
  'url',
  'phone',
] as const

export function SettingsIndexPage() {
  return () => {
    let permissions = signedIn()?.permissions
    let sections = settingsCards().filter((section) => canSee(section.area, permissions))
    return (
      <Shell title="Settings" eyebrow="Workspace">
        {sections.length < settingsCards().length ? (
          <p class="sub mute">
            Some workspace settings, such as webhooks, import and the careers page, are managed by owners and
            admins.
          </p>
        ) : null}
        <div class="settings-directory">
          {sections.map((section) => (
            <a key={section.href} class="settings-directory-link" href={section.href}>
              <h2>{section.title}</h2>
              {section.blurb ? <p class="sub">{section.blurb}</p> : null}
            </a>
          ))}
        </div>
      </Shell>
    )
  }
}

function Notice(handle: Handle<{ notice?: string; error?: string }>) {
  return () => {
    let { notice, error } = handle.props
    if (error)
      return (
        <p role="alert" mix={css({ color: color.danger, fontWeight: 600, margin: '0 0 16px' })}>
          {error}
        </p>
      )
    if (notice)
      return (
        <p role="status" mix={css({ color: color.accent, fontWeight: 600, margin: '0 0 16px' })}>
          {notice}
        </p>
      )
    return null
  }
}

/** A token shown once, right after it is created. */
function OneTimeToken(handle: Handle<{ token?: string }>) {
  return () =>
    handle.props.token ? (
      <div
        role="status"
        mix={css({
          margin: '0 0 24px',
          padding: '16px',
          border: `1px solid ${color.accent}`,
          borderRadius: '10px',
          background: color.surface,
        })}
      >
        <p mix={css({ margin: '0 0 8px', fontWeight: 600 })}>
          Copy this token now. It will not be shown again.
        </p>
        <code
          data-testid="new-token"
          mix={css({ display: 'block', wordBreak: 'break-all', fontSize: '14px', color: color.text })}
        >
          {handle.props.token}
        </code>
      </div>
    ) : null
}

function ScopePicker() {
  return () => (
    <fieldset
      mix={css({
        border: `1px solid ${color.border}`,
        borderRadius: '10px',
        padding: '12px 16px',
        margin: '0 0 16px',
      })}
    >
      <legend mix={css({ fontSize: '13px', color: color.textMuted, padding: '0 6px' })}>Scopes</legend>
      <p mix={css({ margin: '0 0 8px', fontSize: '13px', color: color.textMuted })}>
        Only scopes your role allows are listed; a scope never grants more than your role.
      </p>
      {grantableScopes(signedIn()?.permissions).map((group) => (
        <div key={group.label} mix={css({ marginBottom: '8px' })}>
          <p
            mix={css({
              margin: '4px 0',
              fontSize: '12px',
              textTransform: 'uppercase',
              letterSpacing: '0.08em',
              color: color.textMuted,
            })}
          >
            {group.label}
          </p>
          {group.scopes.map((scope) => (
            <label
              key={scope.key}
              mix={css({
                display: 'flex',
                gap: '8px',
                alignItems: 'center',
                padding: '8px 0',
                minHeight: '28px',
                fontSize: '14px',
              })}
            >
              <input type="checkbox" name="scopes" value={scope.key} />
              {scope.label}
            </label>
          ))}
        </div>
      ))}
    </fieldset>
  )
}

function TextInput(
  handle: Handle<{ label: string; name: string; required?: boolean; placeholder?: string }>,
) {
  return () => (
    <Field
      label={handle.props.label}
      name={handle.props.name}
      required={handle.props.required}
      placeholder={handle.props.placeholder}
    />
  )
}

function InlineButton(
  handle: Handle<{ intent: string; value?: string; children?: RemixNode; tone?: 'danger' }>,
) {
  return () => (
    <button
      type="submit"
      name="intent"
      value={handle.props.intent}
      class="btn btn-ghost btn-small"
      mix={css({ color: handle.props.tone === 'danger' ? color.danger : color.text })}
    >
      {handle.props.children}
    </button>
  )
}

const statusTone: Record<string, string> = {
  active: color.success,
  paused: color.warning,
  revoked: color.danger,
}

export function AgentsPage(
  handle: Handle<{
    agents: AgentRecord[]
    actingAgentId?: string
    token?: string
    notice?: string
    error?: string
  }>,
) {
  return () => {
    let { agents, actingAgentId, token, notice, error } = handle.props
    let action = routes.settingsAgents.action.href()
    return (
      <Shell title="Agents" eyebrow="Settings" wide>
        <Mute>
          An agent acts with the scopes you give it, never more than your own role allows. Audit records the
          agent as the actor and you as the person it acted for.
        </Mute>
        <Notice notice={notice} error={error} />
        <OneTimeToken token={token} />
        <div
          mix={css({
            display: 'grid',
            gridTemplateColumns: 'minmax(0, 3fr) minmax(260px, 2fr)',
            gap: '24px',
            '@media (max-width: 820px)': { gridTemplateColumns: '1fr' },
          })}
        >
          <section aria-label="Your agents">
            {agents.length === 0 ? (
              <EmptyState>No agents yet. Create one to hand work to MCP clients or automations.</EmptyState>
            ) : (
              <ul mix={css({ listStyle: 'none', margin: 0, padding: 0 })}>
                {agents.map((agent) => (
                  <li
                    key={agent.id}
                    mix={css({ padding: '16px 0', borderBottom: `1px solid ${color.border}` })}
                  >
                    <div
                      mix={css({
                        display: 'flex',
                        justifyContent: 'space-between',
                        gap: '12px',
                        alignItems: 'baseline',
                        flexWrap: 'wrap',
                      })}
                    >
                      <strong mix={css({ fontSize: '17px' })}>{agent.name}</strong>
                      <span
                        mix={css({
                          fontSize: '12px',
                          textTransform: 'uppercase',
                          letterSpacing: '0.08em',
                          color: statusTone[agent.status] ?? color.textMuted,
                        })}
                      >
                        {agent.id === actingAgentId ? 'acting now' : agent.status}
                      </span>
                    </div>
                    {agent.description ? (
                      <p mix={css({ margin: '4px 0', color: color.textMuted })}>{agent.description}</p>
                    ) : null}
                    <p mix={css({ margin: '6px 0 10px', fontSize: '13px', color: color.textMuted })}>
                      {agent.scopes.map((scope) => scopeLabel(scope)).join(' · ')}
                    </p>
                    {agent.status === 'revoked' ? null : (
                      <form
                        method="post"
                        action={action}
                        mix={css({ display: 'flex', flexWrap: 'wrap', gap: '8px' })}
                      >
                        <input type="hidden" name="agent_id" value={agent.id} />
                        <input type="hidden" name="agent_name" value={agent.name} />
                        {agent.status === 'active' ? (
                          agent.id === actingAgentId ? (
                            <InlineButton intent="stop-acting">Stop acting</InlineButton>
                          ) : (
                            <InlineButton intent="act-as">Act as this agent</InlineButton>
                          )
                        ) : null}
                        <InlineButton intent="issue-token">New token</InlineButton>
                        {agent.status === 'active' ? (
                          <InlineButton intent="pause">Pause</InlineButton>
                        ) : (
                          <InlineButton intent="resume">Resume</InlineButton>
                        )}
                        <InlineButton intent="revoke" tone="danger">
                          Revoke
                        </InlineButton>
                      </form>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </section>
          <form method="post" action={action} aria-label="Create agent">
            <input type="hidden" name="intent" value="create" />
            <h2
              mix={css({
                fontFamily: font.ui,
                fontSize: 'var(--bb-type-section)',
                margin: '0 0 14px',
                color: color.accent,
              })}
            >
              New agent
            </h2>
            <TextInput label="Name" name="name" required placeholder="Sourcing assistant" />
            <TextInput label="What it does (optional)" name="description" />
            <ScopePicker />
            <PrimaryButton type="submit">Create agent</PrimaryButton>
          </form>
        </div>
        <section class="section-card" aria-label="MCP">
          <h2>MCP</h2>
          <p class="sub">
            Point an MCP client at this workspace with the token you just issued. The server speaks the same
            API as the CLI and the UI. Set <span class="mono">BIGBUCK_TOKEN</span> and{' '}
            <span class="mono">BIGBUCK_API_URL</span>, then run the Big Buck MCP server. Writes stay off until
            you allow them.
          </p>
          <p class="sub">Activity those agents take shows up on Today.</p>
        </section>
      </Shell>
    )
  }
}

export function KeysPage(
  handle: Handle<{ credentials: CredentialRecord[]; token?: string; notice?: string; error?: string }>,
) {
  return () => {
    let { credentials, token, notice, error } = handle.props
    let action = routes.settingsKeys.action.href()
    let live = credentials.filter((c) => c.status === 'active')
    return (
      <Shell title="API keys" eyebrow="Settings" wide>
        <Mute>
          Personal tokens act as you, limited to the scopes you pick. Agent tokens are managed on the Agents
          page.
        </Mute>
        <Notice notice={notice} error={error} />
        <OneTimeToken token={token} />
        <div
          mix={css({
            display: 'grid',
            gridTemplateColumns: 'minmax(0, 3fr) minmax(260px, 2fr)',
            gap: '24px',
            '@media (max-width: 820px)': { gridTemplateColumns: '1fr' },
          })}
        >
          <section aria-label="Active keys">
            {live.length === 0 ? (
              <EmptyState>No active keys.</EmptyState>
            ) : (
              <div class="table-wrap" role="region" aria-label="Active API keys" tabIndex={0}>
                <table
                  class="table"
                  mix={css({ width: '100%', borderCollapse: 'collapse', fontSize: '14px' })}
                >
                  <thead>
                    <tr>
                      {['Name', 'Kind', 'Scopes', 'Prefix', 'Expires', 'Last used', ''].map((h) => (
                        <th
                          key={h}
                          mix={css({
                            textAlign: 'left',
                            padding: '8px 6px',
                            color: color.textMuted,
                            fontWeight: 500,
                            borderBottom: `1px solid ${color.controlBorder}`,
                          })}
                        >
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {live.map((cred) => (
                      <tr key={cred.id}>
                        <td mix={cell}>{cred.name}</td>
                        <td mix={cell}>{label(cred.kind)}</td>
                        <td mix={cell}>{cred.scopes.map((scope) => scopeLabel(scope)).join(', ') || '—'}</td>
                        <td mix={cell}>
                          <code>{cred.token_prefix}…</code>
                        </td>
                        <td mix={cell}>
                          {cred.expires_at
                            ? new Date(cred.expires_at).toLocaleDateString('en-US', {
                                month: 'short',
                                day: 'numeric',
                                year: 'numeric',
                              })
                            : 'No expiry'}
                        </td>
                        <td mix={cell}>
                          {cred.last_used_at ? new Date(cred.last_used_at).toLocaleDateString() : 'never'}
                        </td>
                        <td mix={cell}>
                          <form method="post" action={action}>
                            <input type="hidden" name="credential_id" value={cred.id} />
                            <InlineButton intent="revoke" tone="danger">
                              Revoke
                            </InlineButton>
                          </form>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
          <form method="post" action={action} aria-label="Create key">
            <input type="hidden" name="intent" value="create" />
            <h2
              mix={css({
                fontFamily: font.ui,
                fontSize: 'var(--bb-type-section)',
                margin: '0 0 14px',
                color: color.accent,
              })}
            >
              New personal key
            </h2>
            <TextInput label="Name" name="name" required placeholder="Laptop CLI" />
            <ScopePicker />
            <PrimaryButton type="submit">Create key</PrimaryButton>
          </form>
        </div>
      </Shell>
    )
  }
}

const cell = css({ padding: '10px 6px', borderBottom: `1px solid ${color.border}`, verticalAlign: 'middle' })

export function FieldsPage(
  handle: Handle<{ entity: string; fields: FieldDef[]; notice?: string; error?: string }>,
) {
  return () => {
    let { entity, fields, notice, error } = handle.props
    let action = `${routes.settingsFields.action.href()}?entity=${entity}`
    return (
      <Shell title="Custom fields" eyebrow="Settings" wide>
        <nav class="tabs" aria-label="Record type">
          {FIELD_ENTITIES.map((e) => (
            <a
              class="tab"
              key={e}
              href={`${routes.settingsFields.index.href()}?entity=${e}`}
              aria-current={e === entity ? 'page' : undefined}
            >
              {e.charAt(0).toUpperCase() + e.slice(1)}
            </a>
          ))}
        </nav>
        <Notice notice={notice} error={error} />
        <div
          mix={css({
            display: 'grid',
            gridTemplateColumns: 'minmax(0, 3fr) minmax(260px, 2fr)',
            gap: '24px',
            '@media (max-width: 820px)': { gridTemplateColumns: '1fr' },
          })}
        >
          <section aria-label="Fields">
            {fields.length === 0 ? (
              <EmptyState>No {entity} fields yet.</EmptyState>
            ) : (
              <ul mix={css({ listStyle: 'none', margin: 0, padding: 0 })}>
                {fields.map((field) => (
                  <li
                    key={field.id}
                    mix={css({
                      display: 'grid',
                      gridTemplateColumns: 'minmax(0, 1fr) auto',
                      gap: '12px',
                      padding: '14px 0',
                      borderBottom: `1px solid ${color.border}`,
                      opacity: field.status === 'archived' ? 0.6 : 1,
                    })}
                  >
                    <span>
                      <strong>{field.label}</strong>{' '}
                      <code mix={css({ fontSize: '12px', color: color.textMuted })}>{field.key}</code>
                      <span
                        mix={css({
                          display: 'block',
                          fontSize: '13px',
                          color: color.textMuted,
                          marginTop: '4px',
                        })}
                      >
                        {field.fieldType} · {field.dataClass} · v{field.version}
                        {field.options.length ? ` · ${field.options.map((o) => o.label).join(', ')}` : ''}
                        {field.status === 'archived' ? ' · archived' : ''}
                      </span>
                    </span>
                    <form method="post" action={action}>
                      <input type="hidden" name="field_id" value={field.id} />
                      <input type="hidden" name="expected_version" value={String(field.version)} />
                      {field.status === 'archived' ? (
                        <InlineButton intent="restore">Restore</InlineButton>
                      ) : (
                        <InlineButton intent="archive">Archive</InlineButton>
                      )}
                    </form>
                  </li>
                ))}
              </ul>
            )}
          </section>
          <form method="post" action={action} aria-label="Add field">
            <input type="hidden" name="intent" value="create" />
            <h2
              mix={css({
                fontFamily: font.ui,
                fontSize: 'var(--bb-type-section)',
                margin: '0 0 14px',
                color: color.accent,
              })}
            >
              Add a {entity} field
            </h2>
            <TextInput label="Label" name="label" required placeholder="Years of experience" />
            <TextInput
              label="Key (lowercase, cannot change later)"
              name="key"
              required
              placeholder="years_experience"
            />
            <label
              class="field"
              mix={css({ display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '14px' })}
            >
              <span mix={css({ fontSize: '13px', color: color.textMuted })}>Type</span>
              <select name="field_type">
                {FIELD_TYPES.map((t) => (
                  <option key={t} value={t}>
                    {t.replace('_', ' ')}
                  </option>
                ))}
              </select>
            </label>
            <label
              class="field"
              mix={css({ display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '14px' })}
            >
              <span mix={css({ fontSize: '13px', color: color.textMuted })}>Data class</span>
              <select name="data_class">
                <option value="internal">internal</option>
                <option value="pii">pii (personal data)</option>
                <option value="sensitive">sensitive</option>
              </select>
            </label>
            <TextInput label="Options, comma-separated (select types)" name="options" />
            <PrimaryButton type="submit">Add field</PrimaryButton>
          </form>
        </div>
      </Shell>
    )
  }
}
