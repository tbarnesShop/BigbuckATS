import type { Handle } from 'remix/component'

import { buildTodayView, withQuery, type CheckItem, type QueueItem } from '../../data/hubs.ts'
import type { FollowUpTask } from '../../data/api.ts'
import type { TodayData } from '../../data/today.ts'
import { routes } from '../../routes.ts'
import { label, whenLabel } from '../../data/labels.ts'
import { FoldSectionTabs } from '../../ui/app-nav.tsx'
import { Shell } from '../../ui/shell.tsx'

/** Personal schedule and feedback lead; visible recruiting queues remain supporting context. */
export function TodayPage(handle: Handle<{ data: TodayData; kind: string | null; orgQuery?: string }>) {
  return () => {
    const p = handle.props
    const { core, offers, jobs, tasks, approvals } = p.data
    const ready = core.status === 'ready' ? core.data : null
    const view = buildTodayView({
      userId: ready?.viewer.user?.id ?? null,
      reviews: ready?.today.reviews ?? [],
      feedback: ready?.today.feedback ?? [],
      upcoming: ready?.today.upcoming ?? [],
      offersPending: offers.status === 'ready' ? offers.data : null,
      jobs: jobs.status === 'ready' ? jobs.data : null,
      kind: p.kind,
      orgQuery: p.orgQuery,
    })
    const retryHref = withQuery(routes.today.href(), { kind: p.kind ?? undefined }, p.orgQuery)
    const partial = [core, offers, jobs].some((section) => section.status === 'failed')
    const omitted = [core, offers, jobs].every((section) => section.status === 'omitted')
    return (
      <Shell title="Today" sub={view.dayLabel} orgQuery={p.orgQuery ?? ''}>
        <FoldSectionTabs label="Today sections" parent="today" orgQuery={p.orgQuery ?? ''} />
        {partial ? (
          <p class="today-partial" role="status">
            Some Today sections couldn’t load. Available sections are shown below.
          </p>
        ) : null}
        {omitted ? <p class="today-empty">Your role doesn’t include this recruiting overview.</p> : null}
        <div class="today-layout">
          <div class="today-main stack">
            {core.status !== 'omitted' ? (
              <>
                <section class="section-card today-section" aria-labelledby="today-interviews-heading">
                  <SectionHeading
                    id="today-interviews-heading"
                    title="Interviews today"
                    count={ready ? view.interviewsToday.length : undefined}
                  />
                  {ready ? (
                    <>
                      {view.interviewsToday.length === 0 ? (
                        <p class="today-empty">No more interviews scheduled today in this view.</p>
                      ) : (
                        <InterviewList items={view.interviewsToday} />
                      )}
                      <a class="today-section-link" href={view.interviewsHref}>
                        View interview schedule →
                      </a>
                    </>
                  ) : (
                    <SectionFailure href={retryHref} />
                  )}
                </section>
                <section
                  id="feedback"
                  class="section-card today-section"
                  aria-labelledby="today-feedback-heading"
                >
                  <SectionHeading
                    id="today-feedback-heading"
                    title="Feedback pending"
                    count={ready ? view.feedbackPending.length : undefined}
                  />
                  {ready ? (
                    view.feedbackPending.length === 0 ? (
                      <p class="today-empty">No scorecards pending in this view.</p>
                    ) : (
                      <QueueList items={view.feedbackPending} feedback canWrite={p.data.canWriteFeedback} />
                    )
                  ) : (
                    <SectionFailure href={retryHref} />
                  )}
                </section>
              </>
            ) : null}
            {approvals.status === 'ready' ? (
              <section
                id="approvals"
                class="section-card today-section"
                aria-labelledby="today-approvals-heading"
              >
                <SectionHeading
                  id="today-approvals-heading"
                  title="Agent approvals"
                  count={approvals.data.rows.length}
                />
                <p class="meta today-context">Nothing sends until you approve.</p>
                {approvals.data.total === 0 ? null : (
                  <ul class="queue today-queue">
                    {approvals.data.rows.map((proposal) => (
                      <li key={proposal.id} class="queue-item">
                        <span class="body">
                          <a
                            class="title"
                            href={`${routes.peopleShow.index.href({ personId: proposal.person_id })}${p.orgQuery ?? ''}`}
                          >
                            {proposal.person?.display_name ?? 'Someone'}
                          </a>
                          <span class="meta">
                            {[proposal.agent?.name, proposal.draft_opener].filter(Boolean).join(' · ')}
                          </span>
                        </span>
                      </li>
                    ))}
                  </ul>
                )}
                <a class="today-section-link" href={`${routes.proposals.index.href()}${p.orgQuery ?? ''}`}>
                  {approvals.data.total > 0
                    ? `Review and approve all ${approvals.data.total} →`
                    : 'All agent proposals →'}
                </a>
              </section>
            ) : null}
            {tasks.status !== 'omitted' ? (
              <section
                id="follow-ups"
                class="section-card today-section"
                aria-labelledby="today-tasks-heading"
              >
                <SectionHeading
                  id="today-tasks-heading"
                  title="Follow-ups"
                  count={tasks.status === 'ready' ? tasks.data.length : undefined}
                />
                <p class="meta today-context">Your open tasks · soonest first</p>
                {tasks.status === 'ready' ? (
                  <>
                    {tasks.data.length === 0 ? (
                      <p class="today-empty">Nothing to follow up on. Add one from a person’s page.</p>
                    ) : (
                      <FollowUpList tasks={tasks.data} orgQuery={p.orgQuery ?? ''} />
                    )}
                    <a class="today-section-link" href={`${routes.tasks.index.href()}${p.orgQuery ?? ''}`}>
                      All tasks →
                    </a>
                  </>
                ) : (
                  <SectionFailure href={retryHref} />
                )}
              </section>
            ) : null}
          </div>
          <aside class="today-side stack" aria-label="Recruiting overview">
            {!omitted ? (
              <div class="section-card today-overview">
                {core.status !== 'omitted' ? (
                  <section
                    id="applications"
                    class="today-section"
                    aria-labelledby="today-applications-heading"
                  >
                    <SectionHeading
                      id="today-applications-heading"
                      title="Applications"
                      count={ready?.today.reviews.length}
                    />
                    <p class="meta today-context">Applicants awaiting initial review</p>
                    {ready ? (
                      <>
                        {ready.today.reviews.length === 0 ? (
                          <p class="today-empty">No applicants awaiting review in this view.</p>
                        ) : p.kind === 'reviews' ? (
                          <QueueList items={view.items.filter((item) => item.kind === 'reviews')} />
                        ) : null}
                        <a
                          class="today-section-link"
                          href={
                            p.kind === 'reviews'
                              ? `${routes.applicationsIndex.href()}${p.orgQuery ?? ''}`
                              : view.applicationsHref
                          }
                        >
                          {p.kind === 'reviews' ? 'All applications →' : 'Review applicants →'}
                        </a>
                      </>
                    ) : (
                      <SectionFailure href={retryHref} />
                    )}
                  </section>
                ) : null}
                {offers.status !== 'omitted' ? (
                  <section class="today-section" aria-labelledby="today-offers-heading">
                    <SectionHeading
                      id="today-offers-heading"
                      title="Offers"
                      count={offers.status === 'ready' ? offers.data.length : undefined}
                    />
                    <p class="meta today-context">Awaiting approval</p>
                    {offers.status === 'ready' ? (
                      <>
                        {offers.data.length === 0 ? (
                          <p class="today-empty">No offers awaiting approval in this view.</p>
                        ) : null}
                        <a class="today-section-link" href={view.offersHref}>
                          View offers →
                        </a>
                      </>
                    ) : (
                      <SectionFailure href={retryHref} />
                    )}
                  </section>
                ) : null}
                {jobs.status !== 'omitted' ? (
                  <section class="today-section" aria-labelledby="today-pipeline-heading">
                    <SectionHeading id="today-pipeline-heading" title="Pipeline" />
                    <p class="meta today-context">Active jobs · application volume</p>
                    {view.jobs ? (
                      <>
                        {view.jobs.length === 0 ? (
                          <p class="today-empty">No active jobs in this view.</p>
                        ) : (
                          <ul class="today-pipeline">
                            {view.jobs.map((job) => (
                              <li key={job.id}>
                                <a href={job.href}>{job.title}</a>
                                <span class="meta">{job.meta}</span>
                              </li>
                            ))}
                          </ul>
                        )}
                        <p class="meta today-section-link">
                          {p.data.canViewAnalytics ? (
                            <>
                              <a href={view.analyticsHref}>Analytics →</a>
                              {' · '}
                            </>
                          ) : null}
                          <a href={view.jobsHref}>All jobs →</a>
                        </p>
                      </>
                    ) : (
                      <SectionFailure href={retryHref} />
                    )}
                  </section>
                ) : null}
              </div>
            ) : null}
            {view.thisWeek.length > 0 ? (
              <section class="section-card today-section" aria-labelledby="today-upcoming-heading">
                <SectionHeading
                  id="today-upcoming-heading"
                  title="Coming up"
                  count={view.thisWeek.length}
                  total={view.thisWeekTotal}
                />
                <p class="meta today-context">Next 7 days</p>
                <InterviewList items={view.thisWeek} />
                <a class="today-section-link" href={view.interviewsHref}>
                  {view.thisWeekTotal > view.thisWeek.length
                    ? `See all ${view.thisWeekTotal} upcoming interviews →`
                    : 'View interview schedule →'}
                </a>
              </section>
            ) : null}
            {p.data.canManageAgents ? (
              <p class="meta today-settings-link">
                <a href={routes.settingsAgents.index.href()}>Manage agents in Settings →</a>
              </p>
            ) : null}
          </aside>
        </div>
      </Shell>
    )
  }
}

function SectionHeading(handle: Handle<{ id: string; title: string; count?: number; total?: number }>) {
  return () => {
    const { count, total } = handle.props
    return (
      <div class="today-section-heading">
        <h2 id={handle.props.id}>{handle.props.title}</h2>
        {count !== undefined ? (
          <span class="today-count">
            {total !== undefined && total > count ? `${count} of ${total}` : `${count} shown`}
          </span>
        ) : null}
      </div>
    )
  }
}

function SectionFailure(handle: Handle<{ href: string }>) {
  return () => (
    <div class="today-section-failure">
      <p>This section couldn’t load.</p>
      <a class="today-section-link" href={handle.props.href}>
        Retry Today →
      </a>
    </div>
  )
}

function FollowUpList(handle: Handle<{ tasks: FollowUpTask[]; orgQuery: string }>) {
  return () => {
    const action = `${routes.tasks.action.href()}${handle.props.orgQuery}`
    return (
      <ol class="today-rows">
        {handle.props.tasks.map((task) => (
          <li key={task.id}>
            <div class="today-row-body">
              <span class="today-row-title">{task.title}</span>
              <span class="meta">
                {label(task.task_type)}
                {task.person ? (
                  <>
                    {' · '}
                    <a href={`/people/${task.person.id}${handle.props.orgQuery}`}>
                      {task.person.display_name}
                    </a>
                  </>
                ) : null}
                {task.due_at ? ` · Due ${whenLabel(task.due_at)}` : ''}
                {task.overdue ? ' · Overdue' : ''}
              </span>
            </div>
            <form method="post" action={action} class="row-actions">
              <input type="hidden" name="id" value={task.id} />
              <input type="hidden" name="return" value="today" />
              <button class="btn btn-small btn-primary" type="submit" name="intent" value="complete">
                Done
              </button>
            </form>
          </li>
        ))}
      </ol>
    )
  }
}

function InterviewList(handle: Handle<{ items: CheckItem[] }>) {
  return () => (
    <ol class="today-rows">
      {handle.props.items.map((item) => (
        <li key={item.id}>
          <div class="today-row-body">
            <a class="today-row-title" href={item.href}>
              {item.title}
            </a>
            <span class="meta">{item.meta}</span>
            <span class="meta">{item.detail}</span>
          </div>
          <a class="btn btn-small btn-ghost" href={item.href}>
            Open
          </a>
        </li>
      ))}
    </ol>
  )
}

function QueueList(handle: Handle<{ items: QueueItem[]; feedback?: boolean; canWrite?: boolean }>) {
  return () => (
    <ol class="today-rows">
      {handle.props.items.map((item) => (
        <li key={item.id}>
          <div class="today-row-body">
            <a class="today-row-title" href={item.href}>
              {item.title}
            </a>
            <span class="meta">{item.why}</span>
          </div>
          <a class="btn btn-small btn-dark" href={item.href}>
            {handle.props.feedback ? (handle.props.canWrite ? 'Write feedback' : 'View interview') : 'Review'}
          </a>
        </li>
      ))}
    </ol>
  )
}
