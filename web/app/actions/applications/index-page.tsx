import type { Handle } from 'remix/component'

import type { Application, Job } from '../../data/api.ts'
import { recordHref } from '../../data/record-return.ts'
import { label, statusTone } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { FoldSectionTabs } from '../../ui/app-nav.tsx'
import { ListPagination, SectionTabs } from '../../ui/page-chrome.tsx'
import { EmptyState, Shell } from '../../ui/shell.tsx'

export type ApplicationsView = 'active' | 'hired' | 'archived' | 'all'

const VIEWS: Array<{ id: ApplicationsView; label: string }> = [
  { id: 'active', label: 'Active' },
  { id: 'hired', label: 'Hired' },
  { id: 'archived', label: 'Archived' },
  { id: 'all', label: 'All' },
]

function hrefFor(
  orgQuery: string,
  filters: { job_id?: string; stage?: string; page?: number; status?: ApplicationsView },
) {
  const params = new URLSearchParams(orgQuery.startsWith('?') ? orgQuery.slice(1) : '')
  if (filters.status && filters.status !== 'active') params.set('status', filters.status)
  else params.delete('status')
  if (filters.job_id) params.set('job_id', filters.job_id)
  else params.delete('job_id')
  if (filters.stage) params.set('stage', filters.stage)
  else params.delete('stage')
  if (filters.page && filters.page > 1) params.set('page', String(filters.page))
  else params.delete('page')
  const text = params.toString()
  return `${routes.applicationsIndex.href()}${text ? `?${text}` : ''}`
}

export function ApplicationsIndexPage(
  handle: Handle<{
    applications: Application[]
    jobs: Job[]
    stages: Array<{ key: string; name: string }>
    orgQuery: string
    jobId: string
    stage: string
    view: ApplicationsView
    page: number
    total: number
    perPage: number
  }>,
) {
  return () => {
    let { applications, jobs, stages, orgQuery, jobId, stage, view, page, total, perPage } = handle.props
    let at = (extra: { job_id?: string; stage?: string; page?: number; status?: ApplicationsView }) =>
      hrefFor(orgQuery, { job_id: jobId, stage, status: view, ...extra })
    let stageName = (application: Application) =>
      application.pipeline?.stages.find((row) => row.key === application.current_stage_key)?.name ??
      stages.find((row) => row.key === application.current_stage_key)?.name ??
      label(application.current_stage_key)
    let pages = Math.max(1, Math.ceil(total / perPage))
    let slug = new URLSearchParams(orgQuery.startsWith('?') ? orgQuery.slice(1) : '').get('slug')
    return (
      <Shell title="Applications" eyebrow="Jobs" orgQuery={orgQuery}>
        <FoldSectionTabs label="Jobs sections" parent="jobs" orgQuery={orgQuery} />
        <div class="list-workspace">
          <SectionTabs
            label="Application status"
            links={VIEWS.map((item) => ({
              href: hrefFor(orgQuery, { job_id: jobId, stage, status: item.id }),
              label: item.label,
              current: item.id === view,
            }))}
          />
          {view === 'archived' ? (
            <p class="sub">Rejected and withdrawn candidates. Their people records and history are kept.</p>
          ) : null}
          <p class="list-count">
            {total} {view === 'all' ? '' : `${VIEWS.find((item) => item.id === view)?.label.toLowerCase()} `}
            {jobId || stage ? 'matching applications' : 'applications'} · {applications.length} shown on this
            page
          </p>
          <form class="list-filters" method="get" action={routes.applicationsIndex.href()}>
            {slug ? <input type="hidden" name="slug" value={slug} /> : null}
            {view !== 'active' ? <input type="hidden" name="status" value={view} /> : null}
            <label class="field">
              <span>Job</span>
              <select name="job_id">
                <option value="">All jobs</option>
                {jobs.map((job) => (
                  <option key={job.id} value={job.id} selected={job.id === jobId}>
                    {job.title}
                  </option>
                ))}
              </select>
            </label>
            <label class="field">
              <span>Stage</span>
              <select name="stage">
                <option value="">Any stage</option>
                {stages.map((row) => (
                  <option key={row.key} value={row.key} selected={row.key === stage}>
                    {row.name}
                  </option>
                ))}
              </select>
            </label>
            <button class="btn btn-primary btn-small" type="submit">
              Filter
            </button>
          </form>
          {applications.length === 0 ? (
            <EmptyState>
              {view === 'archived'
                ? 'No archived applications match.'
                : view === 'hired'
                  ? 'No hires match yet.'
                  : 'No applications match.'}{' '}
              <a href={`${routes.jobsIndex.href()}${orgQuery}`}>Open a job</a> or{' '}
              <a href={hrefFor(orgQuery, { status: view })}>clear filters</a>.
            </EmptyState>
          ) : (
            <div class="table-wrap" role="region" aria-label="Application results" tabIndex={0}>
              <table class="table">
                <thead>
                  <tr>
                    <th>Candidate</th>
                    <th>Job</th>
                    <th>Stage</th>
                    <th>Status</th>
                    {view !== 'active' ? <th>Reason</th> : null}
                  </tr>
                </thead>
                <tbody>
                  {applications.map((application) => (
                    <tr key={application.id}>
                      <td>
                        <a
                          href={recordHref(
                            routes.applicationsShow.index.href({ applicationId: application.id }),
                            orgQuery,
                            at({ page }),
                          )}
                        >
                          {application.person?.display_name ?? 'Candidate'}
                        </a>
                        {application.person?.primary_email ? (
                          <div class="list-meta">{application.person.primary_email}</div>
                        ) : null}
                      </td>
                      <td>
                        <a href={`${routes.jobsShow.index.href({ jobId: application.job_id })}${orgQuery}`}>
                          {application.job?.title ?? 'Job'}
                        </a>
                      </td>
                      <td>{stageName(application)}</td>
                      <td>
                        <span class={statusTone(application.status)}>{label(application.status)}</span>
                        {application.closed_at ? (
                          <div class="list-meta">
                            {new Date(application.closed_at).toLocaleDateString('en-US', {
                              month: 'short',
                              day: 'numeric',
                              year: 'numeric',
                            })}
                          </div>
                        ) : null}
                      </td>
                      {view !== 'active' ? <td>{application.closed_reason ?? '—'}</td> : null}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          <ListPagination
            page={page}
            pages={pages}
            prevHref={page > 1 ? at({ page: page - 1 }) : undefined}
            nextHref={page < pages ? at({ page: page + 1 }) : undefined}
          />
        </div>
      </Shell>
    )
  }
}
