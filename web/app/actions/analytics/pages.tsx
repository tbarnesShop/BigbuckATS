import type { Handle } from 'remix/component'

import type { FunnelAnalytics, OutreachFunnel, Sequence, SourcingAnalytics } from '../../data/api.ts'
import { label } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { FoldSectionTabs } from '../../ui/app-nav.tsx'
import { EmptyState, Shell } from '../../ui/shell.tsx'

const percent = (part: number, whole: number) => (whole > 0 ? `${Math.round((part / whole) * 100)}%` : '—')

/** Reply labels in the order a recruiter reads them: good news first, then the rest. */
const REPLY_ORDER = [
  'interested',
  'question',
  'not_interested',
  'unsubscribe',
  'other',
  'out_of_office',
  'bounce',
]

function Stat(handle: Handle<{ name: string; value: string; note?: string }>) {
  return () => (
    <div class="stat-card">
      <span class="sub">{handle.props.name}</span>
      <strong class="stat-value">{handle.props.value}</strong>
      {handle.props.note ? <span class="hint">{handle.props.note}</span> : null}
    </div>
  )
}

function Counts(handle: Handle<{ rows: Array<[string, string]> }>) {
  return () => (
    <dl class="meta-grid">
      {handle.props.rows.map(([name, value]) => (
        <div key={name} class="meta-row">
          <dt>{name}</dt>
          <dd>{value}</dd>
        </div>
      ))}
    </dl>
  )
}

export function AnalyticsPage(
  handle: Handle<{
    funnel: FunnelAnalytics
    sourcing: SourcingAnalytics
    outreach?: OutreachFunnel | null
    perSequence?: Array<{ sequence: Sequence; result: OutreachFunnel }>
    orgQuery: string
  }>,
) {
  return () => {
    let { funnel, sourcing, outreach, perSequence = [], orgQuery } = handle.props
    let funnelRows: Array<[string, string]> = [
      ['Applications', String(funnel.total_applications)],
      ['Hired', String(funnel.hired)],
      ['Rejected', String(funnel.rejected)],
      ...Object.entries(funnel.active_by_stage || {}).map(
        ([key, count]) => [`Active in ${label(key)}`, String(count)] as [string, string],
      ),
    ]
    let sourcingRows: Array<[string, string]> = [
      ['Active sequences', String(sourcing.active_sequences)],
      ['Emails sent', String(sourcing.outbound_messages)],
      ['Replies received', String(sourcing.inbound_replies)],
      ['Reply rate', `${Math.round((sourcing.reply_rate || 0) * 1000) / 10}%`],
      ...Object.entries(sourcing.enrollments_by_status || {}).map(
        ([key, count]) => [`Enrollments: ${label(key)}`, String(count)] as [string, string],
      ),
      ...Object.entries(sourcing.referrals_by_status || {}).map(
        ([key, count]) => [`Referrals: ${label(key)}`, String(count)] as [string, string],
      ),
    ]
    let replies = outreach
      ? REPLY_ORDER.map((key) => [key, outreach.by_classification?.[key] ?? 0] as const).filter(
          ([, count]) => count > 0,
        )
      : []
    let ranked = [...perSequence]
      .filter((row) => row.result.contacted > 0 || row.result.enrolled > 0)
      .sort((a, b) => b.result.contacted - a.result.contacted)
    return (
      <Shell title="Analytics" eyebrow="Today" orgQuery={orgQuery}>
        <FoldSectionTabs label="Today sections" parent="today" orgQuery={orgQuery} />

        {outreach ? (
          <section class="record-section" aria-label="Outreach results">
            <h2>Outreach, last 30 days</h2>
            <p class="sub">
              Each number counts people, not emails: someone who got three steps of a sequence is one person
              contacted.
            </p>
            <div class="cards-grid analytics-stats">
              <Stat name="Enrolled" value={String(outreach.enrolled)} />
              <Stat name="Contacted" value={String(outreach.contacted)} />
              <Stat
                name="Replied"
                value={String(outreach.replied)}
                note={`${percent(outreach.replied, outreach.contacted)} of contacted`}
              />
              <Stat
                name="Positive replies"
                value={String(outreach.positive_replies)}
                note="Interested or asked a question"
              />
              <Stat
                name="Applied"
                value={String(outreach.applied)}
                note={`${percent(outreach.applied, outreach.contacted)} of contacted`}
              />
              <Stat name="Hired" value={String(outreach.hired)} />
            </div>

            <h3>How people replied</h3>
            {replies.length === 0 ? (
              <EmptyState>
                {outreach.replied > 0
                  ? `${outreach.replied} ${outreach.replied === 1 ? 'person' : 'people'} replied, but no reply has been marked yet. Open a reply on the person's activity to mark it.`
                  : 'No replies in the last 30 days.'}
              </EmptyState>
            ) : (
              <Counts rows={replies.map(([key, count]) => [label(key), String(count)])} />
            )}

            <h3>By sequence</h3>
            {ranked.length === 0 ? (
              <EmptyState>No sequence has contacted anyone in the last 30 days.</EmptyState>
            ) : (
              <div class="table-wrap" role="region" aria-label="Results by sequence" tabIndex={0}>
                <table class="table">
                  <thead>
                    <tr>
                      <th>Sequence</th>
                      <th>Contacted</th>
                      <th>Replied</th>
                      <th>Reply rate</th>
                      <th>Interested</th>
                      <th>Applied</th>
                      <th>Hired</th>
                    </tr>
                  </thead>
                  <tbody>
                    {ranked.map(({ sequence, result }) => (
                      <tr key={sequence.id}>
                        <td>
                          <a
                            href={`${routes.sequencesShow.index.href({ sequenceId: sequence.id })}${orgQuery}`}
                          >
                            {sequence.name}
                          </a>
                        </td>
                        <td>{result.contacted}</td>
                        <td>{result.replied}</td>
                        <td>{percent(result.replied, result.contacted)}</td>
                        <td>{result.by_classification?.interested ?? 0}</td>
                        <td>{result.applied}</td>
                        <td>{result.hired}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        ) : null}

        <div class="workflow-grid analytics-grid">
          <section class="record-section">
            <h2>Hiring funnel</h2>
            <Counts rows={funnelRows} />
          </section>
          <section class="record-section">
            <h2>Sourcing, all time</h2>
            <Counts rows={sourcingRows} />
          </section>
        </div>
      </Shell>
    )
  }
}
