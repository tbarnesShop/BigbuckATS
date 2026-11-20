import type { Handle } from 'remix/component'

import type { Job } from '../../data/api.ts'
import { jobStatusChip, openingsLabel } from '../../data/board.ts'
import { label } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { FoldSectionTabs } from '../../ui/app-nav.tsx'
import { SectionTabs } from '../../ui/page-chrome.tsx'
import { EmptyState, Field, PrimaryButton, Shell } from '../../ui/shell.tsx'

const JOB_STATUS_VIEWS = [
  ['', 'All'],
  ['active', 'Active'],
  ['draft', 'Draft'],
  ['paused', 'Paused'],
  ['closed', 'Closed'],
] as const

export function JobsIndexPage(
  handle: Handle<{ jobs: Job[]; orgQuery: string; notice?: string; status?: string }>,
) {
  return () => {
    let { jobs, orgQuery, notice, status = '' } = handle.props
    let shown = status ? jobs.filter((job) => job.status === status) : jobs
    let href = (value: string) => {
      let params = new URLSearchParams(orgQuery.startsWith('?') ? orgQuery.slice(1) : '')
      if (value) params.set('status', value)
      else params.delete('status')
      let text = params.toString()
      return `${routes.jobsIndex.href()}${text ? `?${text}` : ''}`
    }
    return (
      <Shell title="Jobs" eyebrow="ATS" orgQuery={orgQuery}>
        <FoldSectionTabs label="Jobs sections" parent="jobs" orgQuery={orgQuery} />
        <SectionTabs
          label="Job status"
          links={JOB_STATUS_VIEWS.map(([value, text]) => ({
            href: href(value),
            label: text,
            current: value === status,
            count: value ? jobs.filter((job) => job.status === value).length : jobs.length,
          }))}
        />
        <p class="list-count">
          {shown.length} {shown.length === 1 ? 'job' : 'jobs'} shown
          {status ? ` · ${label(status).toLowerCase()}` : ''}.
        </p>
        {notice ? <p class="notice">{notice}</p> : null}
        {shown.length === 0 ? (
          <EmptyState>
            {status
              ? `No ${label(status).toLowerCase()} jobs.`
              : 'No open roles yet. Create a job to start a pipeline.'}
          </EmptyState>
        ) : (
          <div class="list-workspace">
            <div class="table-wrap" role="region" aria-label="Jobs results" tabIndex={0}>
              <table class="table">
                <thead>
                  <tr>
                    <th>Role</th>
                    <th>Status</th>
                    <th>Careers</th>
                    <th>Openings</th>
                    <th>Hiring team</th>
                  </tr>
                </thead>
                <tbody>
                  {shown.map((job) => {
                    let team = job.hiring_team ?? []
                    let lead = team.filter(
                      (member) => member.role === 'hiring-manager' || member.role === 'recruiter',
                    )
                    let others = team.length - lead.length
                    return (
                      <tr key={job.id}>
                        <td>
                          <a href={`${routes.jobsShow.index.href({ jobId: job.id })}${orgQuery}`}>
                            {job.title}
                          </a>
                        </td>
                        <td>
                          <span class={jobStatusChip(job.status).className}>
                            {jobStatusChip(job.status).label}
                          </span>
                        </td>
                        <td>
                          {job.careers_published
                            ? label(job.careers_visibility ?? 'public')
                            : job.careers_visibility === 'hidden'
                              ? 'Hidden'
                              : 'Not published'}
                        </td>
                        <td>{typeof job.openings === 'number' ? openingsLabel(job.openings) : '—'}</td>
                        <td>
                          {team.length === 0
                            ? '—'
                            : `${lead.map((member) => `${member.name ?? 'Member'} (${label(member.role)})`).join(', ') || 'No lead'}${others > 0 ? ` +${others} more` : ''}`}
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </Shell>
    )
  }
}

export function JobCreatePage(
  handle: Handle<{
    orgQuery: string
    notice?: string
    title?: string
    audience?: string
    location?: string
    employmentType?: string
    description?: string
    templates?: Array<{ id: string; name: string }>
    templateId?: string
    departments?: Array<{ id: string; label: string }>
    departmentId?: string
    managers?: Array<{ user_id: string; name: string; role_key?: string | null }>
    hiringManagerId?: string
  }>,
) {
  return () => {
    let { orgQuery, notice } = handle.props
    let departments = handle.props.departments ?? []
    let managers = handle.props.managers ?? []
    return (
      <Shell
        title="New job"
        eyebrow="Jobs"
        orgQuery={orgQuery}
        backHref={`${routes.jobsIndex.href()}${orgQuery}`}
        backLabel="Jobs"
      >
        <FoldSectionTabs label="Jobs sections" parent="jobs" orgQuery={orgQuery} />
        {notice ? (
          <p class="notice" role="alert">
            {notice}
          </p>
        ) : null}
        <form method="post" action={`${routes.jobsCreate.action.href()}${orgQuery}`} class="form-narrow">
          <Field label="Title" name="title" required defaultValue={handle.props.title} />
          <label class="field">
            <span>Careers audience</span>
            <select name="careers_visibility" aria-label="Careers audience">
              <option value="public" selected={(handle.props.audience ?? 'public') === 'public'}>
                Public
              </option>
              <option value="internal" selected={(handle.props.audience ?? 'public') === 'internal'}>
                Internal employees
              </option>
              <option value="both" selected={(handle.props.audience ?? 'public') === 'both'}>
                Public and internal
              </option>
              <option value="hidden" selected={(handle.props.audience ?? 'public') === 'hidden'}>
                Hidden
              </option>
            </select>
          </label>
          {departments.length || managers.length ? (
            <div class="form-row">
              {departments.length ? (
                <label class="field">
                  <span>Department</span>
                  <select name="department_id">
                    <option value="">No department</option>
                    {departments.map((row) => (
                      <option key={row.id} value={row.id} selected={row.id === handle.props.departmentId}>
                        {row.label}
                      </option>
                    ))}
                  </select>
                </label>
              ) : null}
              {managers.length ? (
                <label class="field">
                  <span>Hiring manager</span>
                  <select name="hiring_manager_user_id">
                    <option value="">Add later</option>
                    {managers.map((row) => (
                      <option
                        key={row.user_id}
                        value={row.user_id}
                        selected={row.user_id === handle.props.hiringManagerId}
                      >
                        {row.name}
                      </option>
                    ))}
                  </select>
                </label>
              ) : null}
            </div>
          ) : null}
          <div class="form-row">
            <Field label="Location" name="location" defaultValue={handle.props.location} />
            <label class="field">
              <span>Employment type</span>
              <select name="employment_type">
                {(
                  [
                    ['full_time', 'Full-time'],
                    ['part_time', 'Part-time'],
                    ['contract', 'Contract'],
                    ['internship', 'Internship'],
                    ['temporary', 'Temporary'],
                  ] as const
                ).map(([value, text]) => (
                  <option
                    key={value}
                    value={value}
                    selected={value === (handle.props.employmentType ?? 'full_time')}
                  >
                    {text}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <label class="field">
            <span>Job description</span>
            <textarea
              name="description"
              rows={8}
              defaultValue={handle.props.description ?? ''}
              maxLength={20000}
            />
          </label>
          {(handle.props.templates ?? []).length ? (
            <label class="field">
              <span>Application questions</span>
              <select name="question_template_id">
                <option value="">Organization questions only</option>
                {(handle.props.templates ?? []).map((template) => (
                  <option
                    key={template.id}
                    value={template.id}
                    selected={template.id === handle.props.templateId}
                  >
                    {template.name} template
                  </option>
                ))}
              </select>
            </label>
          ) : null}
          <p class="sub">
            Unless the audience is Hidden, the role is published to careers straight away, and you join its
            hiring team as recruiter. The hiring manager approves the job’s offers; without one, offers go to
            the workspace owner.
          </p>
          <div class="form-actions">
            <PrimaryButton type="submit">Create job</PrimaryButton>
            <a class="btn btn-ghost" href={`${routes.jobsIndex.href()}${orgQuery}`}>
              Cancel
            </a>
          </div>
        </form>
      </Shell>
    )
  }
}
