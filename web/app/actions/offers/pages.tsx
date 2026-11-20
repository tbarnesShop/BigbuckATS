import type { Handle } from 'remix/component'

import { signedIn } from '../../data/auth.ts'
import type { Offer } from '../../data/api.ts'
import {
  OFFER_TABS,
  formatAgo,
  offerEmptyCopy,
  offerHref,
  offerStatus,
  offerTabById,
  offersTabHref,
  personLabel,
  type HubOffer,
  type OfferTabId,
} from '../../data/hubs.ts'
import { label, statusTone } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { PageSubhead, SectionTabs } from '../../ui/page-chrome.tsx'
import { Field, Mute, PrimaryButton, Shell } from '../../ui/shell.tsx'

/** Offers by status. Counts stay on the tabs while the table follows the selection. Approve is pending approval. */
export function OffersHubPage(
  handle: Handle<{
    tab: OfferTabId
    counts: Record<string, number>
    offers: HubOffer[]
    orgQuery?: string
  }>,
) {
  return () => {
    let { tab, counts, offers, orgQuery = '' } = handle.props
    let current = offerTabById(tab)
    return (
      <Shell title="Offers" orgQuery={orgQuery}>
        <div class="stack list-workspace">
          <SectionTabs
            label="Offers by state"
            links={OFFER_TABS.map((item) => ({
              href: offersTabHref(item.id, orgQuery),
              label: item.label,
              current: item.id === tab,
              count: counts[item.status] ?? 0,
            }))}
          />
          <p class="sub mute">{offers.length} offers shown</p>
          <section class="record-section stack" aria-label={current.label}>
            {offers.length === 0 ? (
              <div class="empty">{offerEmptyCopy(tab)}</div>
            ) : (
              <div class="table-wrap" role="region" aria-label="Offers results" tabIndex={0}>
                <table class="table">
                  <thead>
                    <tr>
                      <th>Candidate</th>
                      <th>Job</th>
                      <th>Status</th>
                      <th>Updated</th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    {offers.map((offer) => {
                      let status = offerStatus(offer.status)
                      return (
                        <tr key={offer.id}>
                          <td>{personLabel(offer.application?.person?.displayName)}</td>
                          <td class="meta">{offer.application?.job?.title ?? '—'}</td>
                          <td>
                            <span class={status.chip}>{status.label}</span>
                          </td>
                          <td class="meta">{formatAgo(offer.updatedAt)}</td>
                          <td class="actions">
                            <a class="btn btn-small btn-ghost" href={offerHref(offer.id, orgQuery)}>
                              Open
                            </a>
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>
      </Shell>
    )
  }
}

type StepState = 'done' | 'current' | 'todo' | 'skipped'

const REFERENCE_STATES = ['not_started', 'in_progress', 'complete', 'waived'] as const
const VERBAL_STATES = ['not_started', 'made', 'accepted'] as const

export function OfferShowPage(
  handle: Handle<{
    offer: Offer
    orgQuery: string
    personName?: string
    jobTitle?: string
    notice?: string
    error?: string
    sendToken?: string
    canApprove?: boolean
    approverNames?: Record<string, string>
  }>,
) {
  return () => {
    let {
      offer,
      orgQuery,
      personName,
      jobTitle,
      notice,
      error,
      sendToken,
      canApprove,
      approverNames = {},
    } = handle.props
    let fields = offer.fields ?? {}
    let action = `${routes.offersShow.action.href({ offerId: offer.id })}${orgQuery}`
    let can = (permission: string) => signedIn()?.permissions?.includes(permission) ?? false
    let subject = personName && jobTitle ? `${personName} · ${jobTitle}` : personName || jobTitle || 'Offer'
    let status = offer.status
    let after = (states: string[]) => states.includes(status)
    let references = offer.checklist?.references
    let verbal = offer.checklist?.verbal
    let hired = offer.application?.status === 'hired'
    let approvals = offer.approvals ?? []
    let pending = offer.pending_approvals ?? []

    let approvalState: StepState = after(['approved', 'sent', 'accepted', 'declined'])
      ? 'done'
      : status === 'pending_approval' || status === 'changes_requested'
        ? 'current'
        : 'todo'
    let steps: Array<{ key: string; title: string; state: StepState; detail: RemixNodeLike }> = [
      {
        key: 'references',
        title: 'References',
        state:
          references?.state === 'complete'
            ? 'done'
            : references?.state === 'waived'
              ? 'skipped'
              : references?.state === 'in_progress'
                ? 'current'
                : 'todo',
        detail: (
          <>
            <p class="sub">
              {label(references?.state ?? 'not_started')}
              {references?.note ? ` · ${references.note}` : ''}
            </p>
            {can('offer.create') && !after(['accepted', 'declined', 'rescinded']) ? (
              <ChecklistForm
                action={action}
                item="references"
                states={REFERENCE_STATES}
                current={references?.state}
              />
            ) : null}
          </>
        ),
      },
      {
        key: 'approval',
        title: 'Approval',
        state: approvalState,
        detail: (
          <>
            {status === 'draft' ? <p class="sub">Not submitted yet.</p> : null}
            {approvals.length ? (
              <ul class="plain-list">
                {approvals.map((row) => (
                  <li key={row.id} class="sub">
                    Step {row.step_position ?? 1} · {row.approver_name ?? 'Assigned approver'} ·{' '}
                    <span class={statusTone(row.status)}>{label(row.status)}</span>
                    {row.status === 'approved' && row.approved_by_name
                      ? ` by ${row.approved_by_name}${row.is_override ? ' (owner override)' : ''}`
                      : ''}
                    {row.reason ? ` · ${label(row.reason)}` : ''}
                  </li>
                ))}
              </ul>
            ) : status === 'pending_approval' ? (
              <p class="sub">
                Waiting for{' '}
                {pending
                  .map(
                    (step) =>
                      (step.approver_user_id ? approverNames[step.approver_user_id] : null) ??
                      'the assigned approver',
                  )
                  .join(', ')}
                .
              </p>
            ) : approvalState === 'done' ? (
              <p class="sub">No approval was required for this offer.</p>
            ) : null}
            {status === 'pending_approval' && canApprove ? (
              <form method="post" action={action}>
                <input type="hidden" name="intent" value="approve" />
                <button class="btn btn-primary btn-small" type="submit">
                  Approve offer
                </button>
              </form>
            ) : null}
            {status === 'pending_approval' && offer.can_override ? (
              <form method="post" action={action} class="inline-form">
                <input type="hidden" name="intent" value="override" />
                <button class="btn btn-ghost btn-small" type="submit">
                  Approve as owner (override)
                </button>
                <span class="sub">Recorded as an owner override on this step.</span>
              </form>
            ) : null}
          </>
        ),
      },
      {
        key: 'verbal',
        title: 'Verbal offer',
        state: verbal?.state === 'accepted' || verbal?.state === 'made' ? 'done' : 'todo',
        detail: (
          <>
            <p class="sub">
              {label(verbal?.state ?? 'not_started')}
              {verbal?.state === 'accepted' ? ' verbally' : ''}
              {verbal?.updated_at
                ? ` · ${new Date(verbal.updated_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`
                : ''}
              {verbal?.note ? ` · ${verbal.note}` : ''}
            </p>
            {can('offer.create') && !after(['accepted', 'declined', 'rescinded']) ? (
              <ChecklistForm action={action} item="verbal" states={VERBAL_STATES} current={verbal?.state} />
            ) : null}
          </>
        ),
      },
      {
        key: 'written',
        title: 'Written offer',
        state: after(['sent', 'accepted', 'declined']) ? 'done' : status === 'approved' ? 'current' : 'todo',
        detail: (
          <>
            <p class="sub">
              {after(['sent', 'accepted', 'declined'])
                ? 'Offer letter sent for signature.'
                : status === 'approved'
                  ? 'Approved and ready to send.'
                  : 'Sent once the offer is approved.'}
            </p>
            {status === 'approved' && can('offer.send') ? (
              <form method="post" action={action} class="inline-form">
                <input type="hidden" name="intent" value="send" />
                <Field label="Send to email (optional)" name="to_email" email />
                <button class="btn btn-primary btn-small" type="submit">
                  Send offer letter
                </button>
              </form>
            ) : null}
            {status === 'sent' && can('offer.send') ? (
              <form method="post" action={action} class="inline-form">
                <input type="hidden" name="intent" value="resend" />
                <button class="btn btn-ghost btn-small" type="submit">
                  Resend offer
                </button>
                <span class="sub">Sends it again with a fresh signing link.</span>
              </form>
            ) : status === 'sent' ? (
              <p class="sub">Waiting for the candidate. The recruiter can resend the offer if needed.</p>
            ) : null}
          </>
        ),
      },
      {
        key: 'answer',
        title: 'Candidate’s answer',
        state: after(['accepted', 'declined']) ? 'done' : status === 'sent' ? 'current' : 'todo',
        detail: (
          <>
            {status === 'accepted' || status === 'declined' || status === 'sent' ? (
              <p class="sub">
                {status === 'accepted'
                  ? 'Accepted.'
                  : status === 'declined'
                    ? 'Declined.'
                    : 'Waiting for the candidate. They answer through the link in their letter.'}
              </p>
            ) : null}
            {status === 'sent' && can('offer.send') ? (
              <form method="post" action={action} class="inline-form">
                <input type="hidden" name="intent" value="record_response" />
                <label class="field">
                  <span>Answered another way?</span>
                  <select name="response" required>
                    <option value="accepted">Accepted</option>
                    <option value="declined">Declined</option>
                  </select>
                </label>
                <Field label="Note (optional)" name="note" />
                <button class="btn btn-primary btn-small" type="submit">
                  Record answer
                </button>
              </form>
            ) : null}
          </>
        ),
      },
      {
        key: 'hired',
        title: 'Hired',
        state: hired ? 'done' : status === 'accepted' ? 'current' : 'todo',
        detail: (
          <>
            {status === 'accepted' && !hired && can('application.move_stage') ? (
              <form method="post" action={action} class="inline-form">
                <input type="hidden" name="intent" value="hire" />
                <button class="btn btn-primary btn-small" type="submit">
                  Mark hired
                </button>
              </form>
            ) : null}
            {hired || status === 'accepted' ? (
              <p class="sub">
                {hired
                  ? 'Candidate marked hired.'
                  : 'Accepted. Mark the candidate hired to move them into the Hired stage.'}
              </p>
            ) : null}
          </>
        ),
      },
    ]

    return (
      <Shell
        title={personName ? `Offer for ${personName}` : 'Offer'}
        eyebrow="Offer"
        orgQuery={orgQuery}
        backHref={`${routes.applicationsShow.index.href({ applicationId: offer.application_id })}${orgQuery}`}
        backLabel="Application"
      >
        <PageSubhead label="Offer summary">
          <span class={statusTone(status)}>{label(status)}</span>
          {hired ? <span class="chip chip-ok">Hired</span> : null}
          <span class="chip">{subject}</span>
        </PageSubhead>
        {notice ? (
          <p class="notice" role="status">
            {notice}
          </p>
        ) : null}
        {error ? (
          <p class="notice-bad" role="alert">
            {error}
          </p>
        ) : null}

        {status === 'draft' && can('offer.create') ? (
          <form method="post" action={action} class="hub-bar">
            <input type="hidden" name="intent" value="submit" />
            <PrimaryButton type="submit">Submit for approval</PrimaryButton>
          </form>
        ) : null}

        <div class="record-workspace">
          <section class="record-section">
            <h2>Offer progress</h2>
            <ol class="checklist">
              {steps.map((step) => (
                <li
                  key={step.key}
                  class={`checklist-item ${step.state === 'done' ? 'is-done' : step.state === 'current' ? 'is-current' : ''}`}
                >
                  <span class="checklist-mark" aria-hidden="true">
                    {step.state === 'done'
                      ? '✓'
                      : step.state === 'skipped'
                        ? '–'
                        : step.state === 'current'
                          ? '•'
                          : ''}
                  </span>
                  <div class="checklist-body">
                    <strong>
                      {step.title}
                      <span class="visually-hidden">
                        {' '}
                        (
                        {step.state === 'done'
                          ? 'done'
                          : step.state === 'current'
                            ? 'in progress'
                            : step.state === 'skipped'
                              ? 'skipped'
                              : 'to do'}
                        )
                      </span>
                    </strong>
                    {step.detail}
                  </div>
                </li>
              ))}
            </ol>
          </section>

          <section class="record-section">
            <h2>Terms</h2>
            {Object.keys(fields).length === 0 ? (
              <Mute>
                {offer.terms_hidden
                  ? 'Compensation terms are set but hidden for your role. People with compensation access, such as the owner, can see them.'
                  : 'No terms entered yet.'}
              </Mute>
            ) : (
              <dl class="field-list">
                {Object.entries(fields).map(([key, value]) => (
                  <div key={key}>
                    <dt>{humanizeField(key)}</dt>
                    <dd>{formatField(key, value, fields)}</dd>
                  </div>
                ))}
              </dl>
            )}
            {sendToken ? (
              <p class="sub">
                Candidate accept link:{' '}
                <a href={routes.offer.index.href({ token: sendToken })}>/offers/{sendToken.slice(0, 12)}…</a>
              </p>
            ) : null}
            {['draft', 'pending_approval', 'approved', 'sent'].includes(status) &&
            can('offer.rescind') &&
            !signedIn()?.lab ? (
              <form method="post" action={action}>
                <input type="hidden" name="intent" value="rescind" />
                <input type="hidden" name="reason_key" value="rescinded" />
                <button class="btn btn-ghost btn-small" type="submit">
                  Rescind offer
                </button>
              </form>
            ) : null}
          </section>
        </div>
      </Shell>
    )
  }
}

type RemixNodeLike = import('remix/component').RemixNode

function ChecklistForm(
  handle: Handle<{
    action: string
    item: 'references' | 'verbal'
    states: readonly string[]
    current?: string
  }>,
) {
  return () => {
    let { action, item, states, current } = handle.props
    return (
      <form method="post" action={action} class="inline-form">
        <input type="hidden" name="intent" value="checklist" />
        <input type="hidden" name="item" value={item} />
        <label class="visually-hidden" for={`checklist-${item}`}>
          {item === 'references' ? 'Reference check status' : 'Verbal offer status'}
        </label>
        <select id={`checklist-${item}`} name="state">
          {states.map((state) => (
            <option key={state} value={state} selected={state === (current ?? 'not_started')}>
              {label(state)}
            </option>
          ))}
        </select>
        <label class="visually-hidden" for={`checklist-note-${item}`}>
          Note
        </label>
        <input id={`checklist-note-${item}`} name="note" placeholder="Note (optional)" maxLength={2000} />
        <button class="btn btn-ghost btn-small" type="submit">
          Save
        </button>
      </form>
    )
  }
}

function humanizeField(key: string): string {
  return key.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

function formatField(key: string, value: unknown, fields: Record<string, unknown>): string {
  if (value == null) return '—'
  if (key === 'base_salary' && typeof value === 'number') {
    let currency = typeof fields.currency === 'string' ? fields.currency : 'USD'
    try {
      return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency,
        maximumFractionDigits: 0,
      }).format(value)
    } catch {
      return `${currency} ${value}`
    }
  }
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
    return String(value)
  }
  return JSON.stringify(value)
}
