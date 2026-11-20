import type { AwaitingSchedule } from '../../data/api.ts'
import type { Handle } from 'remix/component'

import {
  INTERVIEW_TABS,
  formatWhen,
  interviewEmptyCopy,
  interviewScope,
  interviewStatus,
  interviewWhy,
  interviewsHref,
  personLabel,
  selectInterviewTab,
  applicationHref,
  interviewHref,
  type HubInterview,
  type InterviewTabId,
} from '../../data/hubs.ts'
import { FilterSegments } from '../../ui/page-chrome.tsx'
import { Shell } from '../../ui/shell.tsx'

/** Upcoming, to schedule, feedback due, and my panels. Mine or all. */
export function InterviewsHubPage(
  handle: Handle<{
    userId: string | null
    lists: Record<InterviewTabId, HubInterview[]>
    /** Candidates whose stage plans interviews nobody has booked yet. */
    awaiting?: AwaitingSchedule[]
    tab: string | null
    scope: string | null
    orgQuery?: string
  }>,
) {
  return () => {
    // The API already narrowed each list to the scope (Mine includes your hiring-team jobs).
    let { lists: visible, orgQuery = '' } = handle.props
    let scope = interviewScope(handle.props.scope)
    let awaiting = handle.props.awaiting ?? []
    let counts = Object.fromEntries(INTERVIEW_TABS.map((tab) => [tab.id, visible[tab.id].length])) as Record<
      InterviewTabId,
      number
    >
    counts.schedule += awaiting.length
    let current = selectInterviewTab(handle.props.tab, counts)
    let rows = visible[current]

    return (
      <Shell title="Interviews" orgQuery={orgQuery}>
        <div class="stack">
          <div class="hub-bar hub-navigation">
            <FilterSegments
              label="Show"
              links={INTERVIEW_TABS.map((tab) => ({
                href: interviewsHref(tab.id, scope, orgQuery),
                label: tab.label,
                current: tab.id === current,
                count: counts[tab.id],
              }))}
            />
            <FilterSegments
              label="Scope"
              links={[
                {
                  href: interviewsHref(current, 'mine', orgQuery),
                  label: 'Mine',
                  current: scope === 'mine',
                },
                {
                  href: interviewsHref(current, 'all', orgQuery),
                  label: 'All',
                  current: scope === 'all',
                },
              ]}
            />
          </div>
          <p class="sub mute">
            {rows.length + (current === 'schedule' ? awaiting.length : 0)} shown ·{' '}
            {scope === 'mine'
              ? 'Mine: your interviews and your hiring-team jobs'
              : 'All: every interview you can see'}
            {current === 'mine'
              ? ' · My panels lists every interview you are an interviewer on, past and upcoming'
              : ''}
          </p>
          {current === 'schedule' ? (
            <section class="record-section stack" aria-label="To schedule">
              <h2>
                To schedule <span class="tab-count">{awaiting.length + rows.length}</span>
              </h2>
              {awaiting.length + rows.length === 0 ? (
                <div class="empty">Every candidate in an interview stage has their interviews booked.</div>
              ) : null}
              {awaiting.length === 0 ? null : (
                <ol class="queue">
                  {awaiting.map((row) => (
                    <li key={row.application_id} class="queue-item">
                      <span class="chip chip-warn">To book</span>
                      <div class="body">
                        <span class="title">{personLabel(row.person?.display_name)}</span>
                        <span class="why">
                          {row.job?.title ?? 'Job'} · {row.stage.name ?? row.stage.key}
                        </span>
                        <span class="meta">
                          Needs {row.missing.map((item) => item.name ?? item.key).join(', ')}
                        </span>
                      </div>
                      <a
                        class="btn btn-dark btn-small"
                        href={`${applicationHref(row.application_id, orgQuery)}#interview-plan`}
                      >
                        Schedule
                      </a>
                    </li>
                  ))}
                </ol>
              )}
            </section>
          ) : null}
          <section
            class="record-section stack"
            aria-label={INTERVIEW_TABS.find((tab) => tab.id === current)?.label}
            hidden={current === 'schedule' && rows.length === 0}
          >
            {rows.length === 0 ? (
              <div class="empty">{interviewEmptyCopy(current)}</div>
            ) : (
              <ol class="queue">
                {rows.map((row) => {
                  let status = interviewStatus(row.status)
                  return (
                    <li key={row.id} class="queue-item">
                      <span class={status.chip}>{status.label}</span>
                      <div class="body">
                        <span class="title">{personLabel(row.application?.person?.displayName)}</span>
                        <span class="why">{interviewWhy(row)}</span>
                        <span class="meta">
                          <time dateTime={row.startsAt ?? undefined}>{formatWhen(row.startsAt)}</time>
                        </span>
                      </div>
                      <a class="btn btn-dark btn-small" href={interviewHref(row.id, orgQuery)}>
                        {current === 'feedback'
                          ? 'Write feedback'
                          : current === 'schedule'
                            ? 'Schedule'
                            : 'Open'}
                      </a>
                    </li>
                  )
                })}
              </ol>
            )}
          </section>
        </div>
      </Shell>
    )
  }
}
