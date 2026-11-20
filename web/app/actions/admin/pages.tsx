import type { Handle } from 'remix/component'
import { css } from 'remix/component'

import type {
  Company,
  CompliancePolicy,
  ConfigPlan,
  DncCompany,
  OutboxEventRow,
  WebhookEndpoint,
} from '../../data/api.ts'
import { routes } from '../../routes.ts'
import { SectionTabs } from '../../ui/page-chrome.tsx'
import { Field, Mute, PrimaryButton, RowList, Shell } from '../../ui/shell.tsx'

const DEFAULT_CONFIG_DOC = `[
  {
    "kind": "PipelineTemplate",
    "key": "engineering-hiring",
    "spec": {
      "name": "Engineering hiring",
      "stages": [
        { "key": "review", "name": "Review", "type": "review" },
        { "key": "onsite", "name": "Onsite", "type": "interview" },
        { "key": "offer", "name": "Offer", "type": "offer" }
      ]
    }
  }
]`

export function AdminPage(
  handle: Handle<{
    companies: Company[]
    dncCompanies: DncCompany[]
    events: OutboxEventRow[]
    webhooks: WebhookEndpoint[]
    plans: ConfigPlan[]
    policies: CompliancePolicy[]
    orgQuery: string
    notice?: string
  }>,
) {
  return () => {
    let { companies, dncCompanies, events, webhooks, plans, policies, orgQuery, notice } = handle.props
    let action = `${routes.admin.action.href()}${orgQuery}`
    return (
      <Shell title="Admin" eyebrow="Platform" orgQuery={orgQuery}>
        <Mute>
          Companies, do-not-contact list, config plan/apply, compliance, webhooks, and outbox events over the
          same REST API.
        </Mute>
        {notice ? (
          <p mix={css({ color: 'var(--bb-accent)', fontWeight: 600, marginBottom: '16px' })}>{notice}</p>
        ) : null}

        <SectionTabs
          label="Admin sections"
          links={[
            { href: '#config', label: 'Configuration' },
            { href: '#compliance', label: 'Compliance' },
            { href: '#companies', label: 'Companies' },
            { href: '#dnc', label: 'Do not contact' },
            { href: '#webhooks', label: 'Webhooks' },
            { href: '#events', label: 'Events' },
          ]}
        />
        <h2 id="config" mix={css({ fontSize: '18px', margin: '8px 0 12px' })}>
          Config as code
        </h2>
        <form method="post" action={action} mix={css({ maxWidth: '40rem', marginBottom: '16px' })}>
          <input type="hidden" name="intent" value="config_plan" />
          <label mix={css({ display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '12px' })}>
            <span mix={css({ fontSize: '13px', fontWeight: 500, color: 'var(--bb-text-muted)' })}>
              Documents (JSON array)
            </span>
            <textarea
              name="documents"
              rows={6}
              required
              defaultValue={DEFAULT_CONFIG_DOC}
              mix={css({
                fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
                fontSize: '13px',
                '@media (max-width: 768px)': { fontSize: '16px' },
                padding: '10px 12px',
                border: '1px solid var(--bb-control-border)',
                background: 'var(--bb-surface)',
              })}
            />
          </label>
          <PrimaryButton type="submit">Create plan</PrimaryButton>
        </form>
        {plans.length === 0 ? (
          <Mute>No config plans yet.</Mute>
        ) : (
          <RowList>
            {plans.map((plan) => (
              <li
                key={plan.id}
                mix={css({
                  listStyle: 'none',
                  padding: '12px 0',
                  borderBottom: '1px solid var(--bb-border)',
                })}
              >
                <strong>{plan.status}</strong>
                <span mix={css({ color: 'var(--bb-text-muted)', marginLeft: '8px', fontSize: '13px' })}>
                  {Array.isArray(plan.change_set) ? `${plan.change_set.length} changes` : '—'} ·{' '}
                  {plan.id.slice(0, 8)}…
                </span>
                {plan.status === 'open' ? (
                  <form method="post" action={action} mix={css({ display: 'inline', marginLeft: '12px' })}>
                    <input type="hidden" name="intent" value="config_apply" />
                    <input type="hidden" name="plan_id" value={plan.id} />
                    <PrimaryButton type="submit">Apply</PrimaryButton>
                  </form>
                ) : null}
              </li>
            ))}
          </RowList>
        )}

        <h2 id="compliance" mix={css({ fontSize: '18px', margin: '28px 0 12px' })}>
          Compliance policies
        </h2>
        {policies.length === 0 ? (
          <Mute>No policies configured (consent gates are open).</Mute>
        ) : (
          <RowList>
            {policies.map((p) => (
              <li
                key={p.id}
                mix={css({
                  listStyle: 'none',
                  padding: '12px 0',
                  borderBottom: '1px solid var(--bb-border)',
                })}
              >
                <strong>{p.name}</strong>
                <span mix={css({ color: 'var(--bb-text-muted)', marginLeft: '8px', fontSize: '13px' })}>
                  {p.key} · priority {p.priority}
                  {p.is_fallback ? ' · fallback' : ''}
                </span>
              </li>
            ))}
          </RowList>
        )}

        <h2 id="companies" mix={css({ fontSize: '18px', margin: '28px 0 12px' })}>
          Companies
        </h2>
        <form method="post" action={action} mix={css({ maxWidth: '28rem', marginBottom: '20px' })}>
          <input type="hidden" name="intent" value="company" />
          <Field label="Name" name="name" required />
          <Field label="Domain" name="domain" />
          <PrimaryButton type="submit">Add company</PrimaryButton>
        </form>
        <RowList>
          {companies.map((c) => (
            <li
              key={c.id}
              mix={css({
                listStyle: 'none',
                padding: '12px 0',
                borderBottom: '1px solid var(--bb-border)',
              })}
            >
              <strong>{c.name}</strong>
              <span mix={css({ color: 'var(--bb-text-muted)', marginLeft: '8px', fontSize: '13px' })}>
                {c.domain ?? '—'} · {c.affiliation_count ?? 0} affiliations
              </span>
            </li>
          ))}
        </RowList>

        <h2 id="dnc" mix={css({ fontSize: '18px', margin: '28px 0 12px' })}>
          Do-not-contact companies
        </h2>
        <Mute>
          Block outreach when a person is affiliated with these companies or email domains. Uses the same
          `/v1/dnc_companies` endpoints as CLI (`bigbuck api createDncCompany`) and MCP.
        </Mute>
        <form method="post" action={action} mix={css({ maxWidth: '28rem', margin: '12px 0 20px' })}>
          <input type="hidden" name="intent" value="dnc_create" />
          <label mix={css({ display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '12px' })}>
            <span mix={css({ fontSize: '13px', fontWeight: 500, color: 'var(--bb-text-muted)' })}>
              Company
            </span>
            <select
              name="company_id"
              mix={css({
                fontSize: '14px',
                '@media (max-width: 768px)': { fontSize: '16px' },
                padding: '10px 12px',
                border: '1px solid var(--bb-control-border)',
                background: 'var(--bb-surface)',
              })}
            >
              <option value="">Optional company</option>
              {companies.map((company) => (
                <option value={company.id} key={company.id}>
                  {company.name}
                  {company.domain ? ` (${company.domain})` : ''}
                </option>
              ))}
            </select>
          </label>
          <Field label="Domain" name="domain" placeholder="example.com" />
          <Field label="Reason" name="reason" placeholder="Existing customer" />
          <PrimaryButton type="submit">Add to DNC</PrimaryButton>
        </form>
        {dncCompanies.length === 0 ? (
          <Mute>No company or domain blocks yet.</Mute>
        ) : (
          <RowList>
            {dncCompanies.map((row) => (
              <li
                key={row.id}
                mix={css({
                  listStyle: 'none',
                  padding: '12px 0',
                  borderBottom: '1px solid var(--bb-border)',
                  display: 'flex',
                  gap: '12px',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  flexWrap: 'wrap',
                })}
              >
                <span>
                  <strong>{row.company?.name ?? row.domain ?? 'Entry'}</strong>
                  <span mix={css({ color: 'var(--bb-text-muted)', marginLeft: '8px', fontSize: '13px' })}>
                    {[row.domain, row.reason].filter(Boolean).join(' · ') || '—'}
                  </span>
                </span>
                <form method="post" action={action}>
                  <input type="hidden" name="intent" value="dnc_delete" />
                  <input type="hidden" name="id" value={row.id} />
                  <button class="btn btn-ghost btn-small" type="submit">
                    Remove
                  </button>
                </form>
              </li>
            ))}
          </RowList>
        )}

        <h2 id="webhooks" mix={css({ fontSize: '18px', margin: '28px 0 12px' })}>
          Webhooks
        </h2>
        <form method="post" action={action} mix={css({ maxWidth: '28rem', marginBottom: '20px' })}>
          <input type="hidden" name="intent" value="webhook" />
          <Field label="Key" name="key" required />
          <Field label="URL" name="url" required />
          <PrimaryButton type="submit">Add webhook</PrimaryButton>
        </form>
        <RowList>
          {webhooks.map((w) => (
            <li
              key={w.id}
              mix={css({
                listStyle: 'none',
                padding: '12px 0',
                borderBottom: '1px solid var(--bb-border)',
              })}
            >
              <strong>{w.key}</strong>
              <span mix={css({ color: 'var(--bb-text-muted)', marginLeft: '8px', fontSize: '13px' })}>
                {w.url} · {w.active ? 'active' : 'off'}
              </span>
            </li>
          ))}
        </RowList>

        <h2 id="events" mix={css({ fontSize: '18px', margin: '28px 0 12px' })}>
          Recent events
        </h2>
        {events.length === 0 ? (
          <Mute>No outbox events yet.</Mute>
        ) : (
          <ol mix={css({ margin: 0, paddingLeft: '1.2rem', display: 'grid', gap: '8px' })}>
            {events.slice(0, 25).map((e) => (
              <li key={e.id} mix={css({ fontSize: '14px' })}>
                <strong>{e.event_type}</strong> · {e.resource_type}/{e.resource_id.slice(0, 8)}
              </li>
            ))}
          </ol>
        )}
      </Shell>
    )
  }
}
