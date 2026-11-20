import type { Handle } from 'remix/component'
import { css } from 'remix/component'

import type { Job, Referral } from '../../data/api.ts'
import { routes } from '../../routes.ts'
import { EmptyState, Field, Mute, PrimaryButton, RowList, Shell } from '../../ui/shell.tsx'
import { color } from '../../ui/tokens.ts'

export function ReferralsPage(
  handle: Handle<{
    referrals: Referral[]
    jobs: Job[]
    orgQuery: string
    notice?: string
  }>,
) {
  return () => {
    let { referrals, jobs, orgQuery, notice } = handle.props
    return (
      <Shell title="Referrals" eyebrow="Attraction" orgQuery={orgQuery}>
        <Mute>Employee referrals with attribution to the referrer and optional job.</Mute>
        {notice ? (
          <p mix={css({ color: color.accent, fontWeight: 600, margin: '16px 0' })}>{notice}</p>
        ) : null}
        <details class="workflow-disclosure" open={Boolean(notice)}>
          <summary>Submit referral</summary>
          <div class="workflow-grid">
            <form
              method="post"
              action={`${routes.referrals.action.href()}${orgQuery}`}
              mix={css({
                maxWidth: '28rem',
                margin: '24px 0',
                paddingBottom: '24px',
                borderBottom: `1px solid ${color.border}`,
              })}
            >
              <h2 mix={css({ fontSize: '16px', margin: '0 0 12px', color: color.accent })}>
                Submit referral
              </h2>
              <Field label="Candidate name" name="display_name" required />
              <Field label="Email" name="email" email />
              <label
                mix={css({
                  display: 'grid',
                  gap: '6px',
                  marginBottom: '16px',
                  fontSize: '13px',
                  color: color.textMuted,
                })}
              >
                Job (optional)
                <select name="job_id" mix={css({ padding: '10px 12px', fontSize: '16px' })}>
                  <option value="">No job yet</option>
                  {jobs.map((job) => (
                    <option value={job.id}>{job.title}</option>
                  ))}
                </select>
              </label>
              <Field label="Note" name="note" />
              <PrimaryButton type="submit">Create referral</PrimaryButton>
            </form>
          </div>
        </details>
        <p class="sub mute">{referrals.length} referrals shown</p>
        {referrals.length === 0 ? (
          <EmptyState>No referrals yet.</EmptyState>
        ) : (
          <RowList>
            {referrals.map((r) => (
              <li
                key={r.id}
                mix={css({
                  listStyle: 'none',
                  padding: '12px 0',
                  borderBottom: `1px solid ${color.border}`,
                })}
              >
                <strong>{r.person?.display_name ?? r.person_id}</strong>
                <span mix={css({ color: color.textMuted, marginLeft: '8px', fontSize: '13px' })}>
                  {[r.status, r.job?.title, r.person?.primary_email].filter(Boolean).join(' · ')}
                </span>
              </li>
            ))}
          </RowList>
        )}
      </Shell>
    )
  }
}
