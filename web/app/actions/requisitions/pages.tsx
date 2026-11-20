import type { Handle } from 'remix/component'
import { css } from 'remix/component'

import type { Requisition } from '../../data/api.ts'
import { routes } from '../../routes.ts'
import { EmptyState, Field, Mute, PrimaryButton, RowList, Shell } from '../../ui/shell.tsx'
import { color } from '../../ui/tokens.ts'
import { label } from '../../data/labels.ts'

export function RequisitionsPage(
  handle: Handle<{ requisitions: Requisition[]; orgQuery: string; notice?: string }>,
) {
  return () => {
    let { requisitions, orgQuery, notice } = handle.props
    return (
      <Shell title="Openings" eyebrow="Headcount" orgQuery={orgQuery}>
        <Mute>Approved demand with headcount. Link jobs to a requisition to track fill.</Mute>
        {notice ? (
          <p mix={css({ color: color.accent, fontWeight: 600, margin: '16px 0' })}>{notice}</p>
        ) : null}
        <details class="workflow-disclosure" open={Boolean(notice)}>
          <summary>New requisition</summary>
          <div class="workflow-grid">
            <form
              method="post"
              action={`${routes.requisitions.action.href()}${orgQuery}`}
              mix={css({
                maxWidth: '28rem',
                margin: '24px 0',
                paddingBottom: '24px',
                borderBottom: `1px solid ${color.border}`,
              })}
            >
              <input type="hidden" name="intent" value="create" />
              <h2 mix={css({ fontSize: '16px', margin: '0 0 12px', color: color.accent })}>
                New requisition
              </h2>
              <Field label="Code" name="code" required />
              <Field label="Title" name="title" required />
              <Field label="Headcount" name="headcount" defaultValue="1" />
              <PrimaryButton type="submit">Create draft</PrimaryButton>
            </form>
          </div>
        </details>
        <p class="sub mute">{requisitions.length} requisitions shown</p>
        {requisitions.length === 0 ? (
          <EmptyState>No requisitions yet.</EmptyState>
        ) : (
          <RowList>
            {requisitions.map((req) => (
              <li
                key={req.id}
                mix={css({
                  listStyle: 'none',
                  padding: '14px 0',
                  borderBottom: `1px solid ${color.border}`,
                  display: 'grid',
                  gap: '8px',
                })}
              >
                <div>
                  <strong>
                    {req.code} · {req.title}
                  </strong>
                  <span mix={css({ color: color.textMuted, marginLeft: '8px', fontSize: '13px' })}>
                    {label(req.status)} · {req.filled_count ?? 0} of {req.headcount} filled
                    {/* A closed requisition has no open seats, whatever was left unfilled. */}
                    {req.status === 'closed' ? '' : ` · ${req.openings_remaining ?? req.headcount} open`}
                  </span>
                </div>
                {req.status !== 'open' && req.status !== 'closed' ? (
                  <form method="post" action={`${routes.requisitions.action.href()}${orgQuery}`}>
                    <input type="hidden" name="intent" value="open" />
                    <input type="hidden" name="requisition_id" value={req.id} />
                    <PrimaryButton type="submit">Open for hiring</PrimaryButton>
                  </form>
                ) : null}
              </li>
            ))}
          </RowList>
        )}
      </Shell>
    )
  }
}
