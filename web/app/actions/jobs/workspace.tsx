import type { Handle } from 'remix/component'

import type { CareersVisibility, RediscoveryHit } from '../../data/api.ts'
import {
  BOARD_SECTIONS,
  JOB_TABS,
  cardsInColumn,
  columnsForSection,
  jobStatusChip,
  jobWorkspaceHref,
  openingsLabel,
  previewMove,
  sectionCount,
  stageAgeLabel,
  stageLabel,
  type BoardSection,
  type JobTab,
  skippedInterviewStages,
  type StageRef,
} from '../../data/board.ts'
import { signedIn } from '../../data/auth.ts'
import { label, statusTone, whenLabel } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { FilterSegments, PageSubhead, SectionTabs } from '../../ui/page-chrome.tsx'
import { EmptyState, Field, Mute, Shell } from '../../ui/shell.tsx'

export type WorkspaceStage = StageRef & {
  key: string
  interviews?: Array<{
    key: string
    name?: string
    required?: boolean
    rubric_key?: string
    duration_minutes?: number
  }>
}

export type WorkspaceApplication = {
  id: string
  status: string
  stageKey: string
  name: string
  email: string | null
  enteredAt: string | null
  /** Next scheduled interview, if any. */
  nextInterview: { name: string; startsAt: string } | null
}

export type WorkspacePool = { id: string; name: string; memberCount: number | null }

export type WorkspaceJob = {
  careersVisibility?: CareersVisibility
  careersPublished?: boolean
  id: string
  title: string
  status: string
  openings: number | null
  confidential: boolean
  codeName: string | null
  stages: WorkspaceStage[]
  requisition: { code: string; title: string; status: string } | null
  dimensions: Array<{ key: string; label: string; value: string }>
  hiringTeam: Array<{ id: string; userId: string; name: string | null; role: string }>
  assignableMembers: Array<{ userId: string; name: string }>
  posting: {
    id: string
    title: string
    description: string
    location: string
    employmentType: string
    version: number
  } | null
  stageCounts: Record<string, number>
  rubrics: Array<{ key: string; name: string }>
}

export function JobWorkspacePage(
  handle: Handle<{
    job: WorkspaceJob
    applications: WorkspaceApplication[]
    pools: WorkspacePool[]
    rediscovery: RediscoveryHit[]
    orgQuery: string
    tab: JobTab
    section: BoardSection
    selectedApplicationId: string
    toStageKey: string
    truncated?: boolean
    notice?: string
    error?: string
    /** Feedback the selected candidate still owes before leaving their stage; undefined when unknown. */
    missingFeedback?: Array<{ key: string; name: string }>
    feedbackBlocks?: boolean
  }>,
) {
  return () => {
    let {
      missingFeedback,
      job,
      applications,
      pools,
      rediscovery,
      orgQuery,
      tab,
      section,
      selectedApplicationId,
      toStageKey,
      truncated,
      notice,
      error,
    } = handle.props
    let status = jobStatusChip(job.status)
    let sourcingCount = rediscovery.length + pools.reduce((sum, pool) => sum + (pool.memberCount ?? 0), 0)
    let counts: Record<JobTab, number> = {
      pipeline: applications.filter((app) => app.status === 'active').length,
      applications: applications.length,
      sourcing: sourcingCount,
      settings: job.hiringTeam.length,
    }
    let jobsHref = `${routes.jobsIndex.href()}${orgQuery}`
    let settingsHref = `${jobWorkspaceHref(job.id, orgQuery, { tab: 'settings' })}#pipeline`

    return (
      <Shell title={job.title} eyebrow="Job" orgQuery={orgQuery} wide backHref={jobsHref} backLabel="Jobs">
        <PageSubhead
          label="Job summary"
          action={
            <a class="btn btn-ghost btn-small" href={settingsHref}>
              Edit pipeline
            </a>
          }
        >
          <span class={status.className}>{status.label}</span>
          {typeof job.openings === 'number' ? <span class="chip">{openingsLabel(job.openings)}</span> : null}
          {job.dimensions.map((dimension) => (
            <span key={`${dimension.key}-${dimension.value}`} class="chip chip-info">
              {dimension.value}
            </span>
          ))}
          {job.confidential ? (
            <span class="chip chip-warn">
              {job.codeName ? `Confidential · ${job.codeName}` : 'Confidential'}
            </span>
          ) : null}
        </PageSubhead>

        <SectionTabs
          label="Job"
          links={JOB_TABS.map((item) => ({
            href: jobWorkspaceHref(job.id, orgQuery, item.id === 'pipeline' ? {} : { tab: item.id }),
            label: item.label,
            current: tab === item.id,
            count: ['pipeline', 'applications'].includes(item.id) ? counts[item.id] : undefined,
          }))}
        />

        {notice ? <p class="notice">{notice}</p> : null}
        {error ? (
          <p class="notice-bad" role="alert">
            {error}
          </p>
        ) : null}
        {error && applications.some((app) => app.id === selectedApplicationId) ? (
          <p>
            <a
              href={`${routes.applicationsShow.index.href({ applicationId: selectedApplicationId })}${orgQuery}`}
            >
              Open candidate’s interview plan
            </a>
          </p>
        ) : null}
        {truncated ? <Mute>Showing the first 200 applications on this job.</Mute> : null}

        {tab === 'pipeline' ? (
          <PipelineTab
            job={job}
            applications={applications}
            orgQuery={orgQuery}
            section={section}
            selectedApplicationId={selectedApplicationId}
            toStageKey={toStageKey}
            missingFeedback={missingFeedback}
            feedbackBlocks={handle.props.feedbackBlocks}
          />
        ) : null}
        {tab === 'applications' ? (
          <ApplicationsTab job={job} applications={applications} orgQuery={orgQuery} />
        ) : null}
        {tab === 'sourcing' ? (
          <SourcingTab jobId={job.id} pools={pools} rediscovery={rediscovery} orgQuery={orgQuery} />
        ) : null}
        {tab === 'settings' ? <SettingsTab job={job} orgQuery={orgQuery} /> : null}
      </Shell>
    )
  }
}

function PipelineTab(
  handle: Handle<{
    job: WorkspaceJob
    applications: WorkspaceApplication[]
    orgQuery: string
    section: BoardSection
    selectedApplicationId: string
    toStageKey: string
    missingFeedback?: Array<{ key: string; name: string }>
    feedbackBlocks?: boolean
  }>,
) {
  return () => {
    let { job, applications, orgQuery, section, selectedApplicationId, toStageKey, missingFeedback } =
      handle.props
    let columns = columnsForSection(section, job.stages, applications)
    let preview = previewMove({
      applicationId: selectedApplicationId,
      toStageKey,
      applications,
      stages: job.stages,
    })
    let skipped = preview?.ok ? skippedInterviewStages(job.stages, preview.fromKey, preview.toKey) : []
    let sectionMeta = BOARD_SECTIONS.find((item) => item.id === section)
    let canMove = signedIn()?.permissions?.includes('application.move_stage') ?? false
    let movable =
      canMove &&
      applications.some(
        (app) => app.status === 'active' && columns.some((stage) => stage.key === app.stageKey),
      )
    let slug = new URLSearchParams(orgQuery.startsWith('?') ? orgQuery.slice(1) : orgQuery).get('slug')

    return (
      <div class="job-workspace">
        <FilterSegments
          label="Filter by stage group"
          links={BOARD_SECTIONS.map((item) => {
            let count = sectionCount(item.id, job.stages, applications)
            return {
              href: jobWorkspaceHref(job.id, orgQuery, { tab: 'pipeline', section: item.id }),
              label: item.label,
              current: section === item.id,
              count,
              empty: count === 0,
            }
          })}
        />

        <p class="list-meta" id="pipeline-help">
          {canMove
            ? 'Select a candidate, then a stage to preview a move. To hire, open the candidate and use Mark hired. '
            : 'Open a candidate for interviews and feedback. '}
          {columns.length > 4 ? (
            <span class="board-scroll-hint" data-columns={Math.min(columns.length, 9)}>
              Scroll sideways for more stages.
            </span>
          ) : null}
        </p>

        {canMove && preview?.ok === false ? (
          <p class="notice-bad" role="alert">
            {preview.message}
          </p>
        ) : null}
        {canMove && preview?.ok ? (
          <section class="section-card" aria-live="polite">
            <h2>Move preview</h2>
            <p>
              Move <strong>{preview.name}</strong> from <strong>{preview.fromLabel}</strong> to{' '}
              <strong>{preview.toLabel}</strong>.
            </p>
            <form method="post" action={`${routes.jobsShow.action.href({ jobId: job.id })}${orgQuery}`}>
              <input type="hidden" name="intent" value="move" />
              <input type="hidden" name="application_id" value={selectedApplicationId} />
              <input type="hidden" name="to_stage_key" value={preview.toKey} />
              <input type="hidden" name="section" value={section} />
              {missingFeedback?.length ? (
                <div class={handle.props.feedbackBlocks ? 'notice-bad' : 'notice-warn'} role="alert">
                  <p>
                    {handle.props.feedbackBlocks
                      ? `${preview.name} still needs feedback in ${preview.fromLabel} before they can move:`
                      : `Feedback is still missing in ${preview.fromLabel}. You can move ${preview.name} anyway:`}
                  </p>
                  <ul>
                    {missingFeedback.map((item) => (
                      <li key={item.key}>{item.name}</li>
                    ))}
                  </ul>
                  <a
                    href={`${routes.applicationsShow.index.href({ applicationId: selectedApplicationId })}${orgQuery}#interview-plan`}
                  >
                    Open their interview plan
                  </a>
                </div>
              ) : null}
              {skipped.length ? (
                <p class="notice-warn" role="alert">
                  This skips {skipped.join(', ')}, which {skipped.length === 1 ? 'has' : 'have'} interviews
                  planned. You can move {preview.name} anyway.
                </p>
              ) : null}
              <Field label="Reason (optional)" name="reason" />
              <button
                class="btn btn-primary"
                type="submit"
                disabled={Boolean(handle.props.feedbackBlocks && missingFeedback?.length)}
              >
                Confirm move
              </button>
            </form>
          </section>
        ) : null}

        {columns.length === 0 ? (
          <EmptyState>
            {section === 'closed'
              ? 'No archived applications.'
              : `No ${sectionMeta?.label ?? section} stages on this pipeline.`}
          </EmptyState>
        ) : (
          <form method="get" action={routes.jobsShow.index.href({ jobId: job.id })}>
            <input type="hidden" name="tab" value="pipeline" />
            <input type="hidden" name="section" value={section} />
            {slug ? <input type="hidden" name="slug" value={slug} /> : null}
            {movable ? (
              <fieldset class="move-bar">
                <legend>Move to</legend>
                {job.stages
                  .filter((stage) => stage.type !== 'hired')
                  .map((stage) => (
                    <button
                      key={stage.key}
                      class={
                        stage.key === toStageKey ? 'btn btn-primary btn-small' : 'btn btn-ghost btn-small'
                      }
                      type="submit"
                      name="to_stage_key"
                      value={stage.key}
                    >
                      {stageLabel(stage, stage.key)}
                    </button>
                  ))}
              </fieldset>
            ) : null}
            <div
              class="board"
              role="region"
              aria-label="Pipeline board"
              aria-describedby="pipeline-help"
              tabIndex={0}
            >
              {columns.map((stage) => {
                let cards = cardsInColumn(section, stage, applications)
                return (
                  <section key={stage.key} class="board-col" aria-label={stageLabel(stage, stage.key)}>
                    <h2 class="board-col-head">
                      {stageLabel(stage, stage.key)}
                      <span class="board-col-count">{cards.length}</span>
                    </h2>
                    {cards.length === 0 ? (
                      <p class="board-empty">No candidates</p>
                    ) : (
                      <ul class="board-cards">
                        {cards.map((app) => {
                          let age = stageAgeLabel(app.enteredAt)
                          return (
                            <li key={app.id} class="board-card">
                              <div class="board-card-top">
                                {canMove && app.status === 'active' ? (
                                  <label class="board-select">
                                    <input
                                      type="radio"
                                      name="application_id"
                                      value={app.id}
                                      checked={app.id === selectedApplicationId}
                                      disabled={app.status !== 'active'}
                                    />
                                    <span class="visually-hidden">Select {app.name}</span>
                                  </label>
                                ) : null}
                                <a
                                  class="board-card-name"
                                  href={`${routes.applicationsShow.index.href({ applicationId: app.id })}${orgQuery}`}
                                >
                                  {app.name}
                                </a>
                              </div>
                              {app.email ? <p class="board-card-meta">{app.email}</p> : null}
                              {app.nextInterview ? (
                                <p class="board-card-scheduled">
                                  <span class="chip chip-ok">Scheduled</span> {app.nextInterview.name} ·{' '}
                                  {whenLabel(app.nextInterview.startsAt)}
                                </p>
                              ) : null}
                              {age ? <p class="board-card-age">{age} in stage</p> : null}
                              {app.status !== 'active' ? (
                                <span class={statusTone(app.status)}>{label(app.status)}</span>
                              ) : null}
                            </li>
                          )
                        })}
                      </ul>
                    )}
                  </section>
                )
              })}
            </div>
          </form>
        )}
      </div>
    )
  }
}

function ApplicationsTab(
  handle: Handle<{
    job: WorkspaceJob
    applications: WorkspaceApplication[]
    orgQuery: string
  }>,
) {
  return () => {
    let { job, applications, orgQuery } = handle.props
    if (applications.length === 0) {
      return <EmptyState>No applications on this job yet.</EmptyState>
    }
    return (
      <div class="table-wrap" role="region" aria-label="Job applications" tabIndex={0}>
        <table class="table">
          <thead>
            <tr>
              <th>Candidate</th>
              <th>Stage</th>
              <th>Status</th>
              <th>Next interview</th>
              <th>In stage</th>
            </tr>
          </thead>
          <tbody>
            {applications.map((app) => {
              let stage = job.stages.find((item) => item.key === app.stageKey)
              let age = stageAgeLabel(app.enteredAt)
              return (
                <tr key={app.id}>
                  <td>
                    <a href={`${routes.applicationsShow.index.href({ applicationId: app.id })}${orgQuery}`}>
                      {app.name}
                    </a>
                    {app.email ? <div class="sub">{app.email}</div> : null}
                  </td>
                  <td>{stageLabel(stage, app.stageKey)}</td>
                  <td>
                    <span class={statusTone(app.status)}>{label(app.status)}</span>
                  </td>
                  <td>
                    {app.nextInterview
                      ? `${app.nextInterview.name} · ${whenLabel(app.nextInterview.startsAt)}`
                      : '—'}
                  </td>
                  <td>{age ?? '—'}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    )
  }
}

function SourcingTab(
  handle: Handle<{
    jobId: string
    pools: WorkspacePool[]
    rediscovery: RediscoveryHit[]
    orgQuery: string
  }>,
) {
  return () => {
    let { jobId, pools, rediscovery, orgQuery } = handle.props
    let action = `${routes.jobsShow.action.href({ jobId })}${orgQuery}`
    return (
      <div class="stack">
        <section class="section-card">
          <h2>Pools</h2>
          <Mute>Talent pools tied to this job. Open a member to convert them into an application.</Mute>
          {pools.length === 0 ? (
            <EmptyState>
              No pools feed this job.{' '}
              <a href={`${routes.poolsCreate.index.href()}${orgQuery}`}>New talent pool</a>
            </EmptyState>
          ) : (
            <ul class="queue">
              {pools.map((pool) => (
                <li key={pool.id} class="queue-item">
                  <div class="body">
                    <a
                      class="title"
                      href={`${routes.poolsShow.index.href({ projectId: pool.id })}${orgQuery}`}
                    >
                      {pool.name}
                    </a>
                    <span class="hint">
                      {pool.memberCount == null
                        ? 'Open to convert'
                        : `${pool.memberCount} ${pool.memberCount === 1 ? 'member' : 'members'}`}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
        <section class="section-card">
          <h2>Rediscovery</h2>
          <Mute>Past applicants and silver medalists not currently active on this job.</Mute>
          <p>
            <a
              class="btn btn-ghost btn-small"
              href={`${routes.jobRediscovery.index.href({ jobId })}${orgQuery}`}
            >
              Rediscovery queue and criteria →
            </a>
          </p>
          {rediscovery.length === 0 ? (
            <EmptyState>
              No rediscovery matches yet. Past applicants and silver medalists show up here to convert.
            </EmptyState>
          ) : (
            <ul class="queue">
              {rediscovery.map((hit) => (
                <li key={hit.person.id} class="queue-item">
                  <div class="body">
                    <a
                      class="title"
                      href={`${routes.peopleShow.index.href({ personId: hit.person.id })}${orgQuery}`}
                    >
                      {hit.person.display_name ?? hit.person.id}
                    </a>
                    <span class="hint">
                      score {hit.score}
                      {hit.reasons.length
                        ? ` · ${hit.reasons.map((reason) => label(reason)).join(', ')}`
                        : ''}
                    </span>
                  </div>
                  <form method="post" action={action}>
                    <input type="hidden" name="intent" value="convert" />
                    <input type="hidden" name="person_id" value={hit.person.id} />
                    <button class="btn btn-small btn-dark" type="submit">
                      Add to job
                    </button>
                  </form>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    )
  }
}

const STAGE_TYPES = [
  ['screen', 'Screen'],
  ['interview', 'Interview'],
  ['review', 'Review'],
  ['offer', 'Offer'],
  ['apply', 'Application review'],
] as const

const TEAM_ROLES = [
  ['interviewer', 'Interviewer'],
  ['hiring-manager', 'Hiring manager'],
  ['recruiter', 'Recruiter'],
  ['coordinator', 'Coordinator'],
] as const

const EMPLOYMENT_TYPES = [
  ['full_time', 'Full-time'],
  ['part_time', 'Part-time'],
  ['contract', 'Contract'],
  ['internship', 'Internship'],
  ['temporary', 'Temporary'],
] as const

function SettingsTab(handle: Handle<{ job: WorkspaceJob; orgQuery: string }>) {
  return () => {
    let { job, orgQuery } = handle.props
    let canManage = signedIn()?.permissions?.includes('job.manage') ?? false
    let action = `${routes.jobsShow.action.href({ jobId: job.id })}${orgQuery}`
    let editable = job.stages.filter((stage) => stage.type !== 'hired')
    return (
      <div class="record-workspace job-settings">
        <FilterSegments
          label="Settings sections"
          links={[
            { href: '#job-posting', label: 'Job posting' },
            { href: '#pipeline', label: 'Pipeline' },
            { href: '#interview-plan', label: 'Interview plan' },
            { href: '#hiring-team', label: 'Hiring team' },
            { href: '#careers', label: 'Careers' },
            { href: '#openings', label: 'Openings' },
          ]}
        />

        <section class="record-section" id="job-posting">
          <h2>Job posting</h2>
          <p class="sub">What candidates read on the careers site and above the application form.</p>
          {job.posting && canManage ? (
            <form method="post" action={action} class="posting-details">
              <input type="hidden" name="intent" value="posting_details" />
              <input type="hidden" name="posting_id" value={job.posting.id} />
              <input type="hidden" name="expected_version" value={String(job.posting.version)} />
              <label class="field">
                <span>Title on careers</span>
                <input name="title" defaultValue={job.posting.title} required maxLength={255} />
              </label>
              <div class="form-row">
                <label class="field">
                  <span>Location</span>
                  <input
                    name="location"
                    defaultValue={job.posting.location}
                    placeholder="Remote — US"
                    maxLength={255}
                  />
                </label>
                <label class="field">
                  <span>Employment type</span>
                  <select name="employment_type">
                    <option value="">Not specified</option>
                    {EMPLOYMENT_TYPES.map(([value, text]) => (
                      <option key={value} value={value} selected={job.posting?.employmentType === value}>
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
                  rows={10}
                  defaultValue={job.posting.description}
                  maxLength={20000}
                />
              </label>
              <p class="sub">
                Plain text. Blank lines start a new paragraph; lines starting with “- ” become a list.
              </p>
              <button class="btn btn-primary btn-small" type="submit">
                Save job posting
              </button>
            </form>
          ) : job.posting ? (
            <div class="posting-preview">
              <p>
                <strong>{job.posting.title}</strong>
                {job.posting.location || job.posting.employmentType
                  ? ` · ${[job.posting.location, job.posting.employmentType && label(job.posting.employmentType)].filter(Boolean).join(' · ')}`
                  : ''}
              </p>
              <p class="sub" style="white-space: pre-line">
                {job.posting.description || 'No description yet.'}
              </p>
            </div>
          ) : (
            <EmptyState>This job has no posting yet. Create one under postings below.</EmptyState>
          )}
          <p>
            <a href={routes.jobPostings.index.href({ jobId: job.id })}>
              {canManage
                ? 'All postings and application questions'
                : 'View postings and application questions'}
            </a>
          </p>
        </section>

        <section class="record-section" id="pipeline">
          <h2>Pipeline</h2>
          <Mute>Stages in the order candidates move through them. Hired is always last.</Mute>
          <div class="table-wrap" role="region" aria-label="Pipeline stages" tabIndex={0}>
            <table class="table pipeline-editor">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Stage</th>
                  <th>Kind</th>
                  <th>Candidates</th>
                  {canManage ? <th>Change</th> : null}
                </tr>
              </thead>
              <tbody>
                {job.stages.map((stage, index) => {
                  let fixed = stage.type === 'hired'
                  let count = job.stageCounts[stage.key] ?? 0
                  let position = editable.findIndex((row) => row.key === stage.key)
                  return (
                    <tr key={stage.key}>
                      <td>{index + 1}</td>
                      <td>
                        {canManage && !fixed ? (
                          <form method="post" action={action} class="inline-form">
                            <input type="hidden" name="intent" value="pipeline" />
                            <input type="hidden" name="op" value="rename_stage" />
                            <input type="hidden" name="key" value={stage.key} />
                            <label class="visually-hidden" for={`stage-name-${stage.key}`}>
                              Name for {stageLabel(stage, stage.key)}
                            </label>
                            <input
                              id={`stage-name-${stage.key}`}
                              name="name"
                              defaultValue={stageLabel(stage, stage.key)}
                              required
                              maxLength={80}
                            />
                            <button class="btn btn-ghost btn-small" type="submit">
                              Rename
                            </button>
                          </form>
                        ) : (
                          stageLabel(stage, stage.key)
                        )}
                      </td>
                      <td>{fixed ? 'Hired' : label(stage.type ?? 'interview')}</td>
                      <td>{count}</td>
                      {canManage ? (
                        <td>
                          {fixed ? (
                            <span class="sub">Fixed</span>
                          ) : (
                            <div class="row-actions">
                              {(
                                [
                                  ['up', '↑', `Move ${stageLabel(stage, stage.key)} earlier`, position === 0],
                                  [
                                    'down',
                                    '↓',
                                    `Move ${stageLabel(stage, stage.key)} later`,
                                    position === editable.length - 1,
                                  ],
                                ] as const
                              ).map(([direction, glyph, name, disabled]) => (
                                <form key={direction} method="post" action={action}>
                                  <input type="hidden" name="intent" value="pipeline" />
                                  <input type="hidden" name="op" value="move_stage" />
                                  <input type="hidden" name="key" value={stage.key} />
                                  <input type="hidden" name="direction" value={direction} />
                                  <button
                                    class="btn btn-ghost btn-small"
                                    type="submit"
                                    aria-label={name}
                                    title={name}
                                    disabled={disabled}
                                  >
                                    {glyph}
                                  </button>
                                </form>
                              ))}
                              <form method="post" action={action}>
                                <input type="hidden" name="intent" value="pipeline" />
                                <input type="hidden" name="op" value="remove_stage" />
                                <input type="hidden" name="key" value={stage.key} />
                                <button
                                  class="btn btn-ghost btn-small"
                                  type="submit"
                                  disabled={count > 0 || editable.length <= 1}
                                  title={count > 0 ? 'Move these candidates out first' : undefined}
                                >
                                  Remove
                                </button>
                              </form>
                            </div>
                          )}
                        </td>
                      ) : null}
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
          {canManage ? (
            <form method="post" action={action} class="hub-bar" autocomplete="off">
              <input type="hidden" name="intent" value="pipeline" />
              <input type="hidden" name="op" value="add_stage" />
              <label class="field">
                <span>New stage</span>
                <input name="name" required maxLength={80} placeholder="e.g. Hiring manager screen" />
              </label>
              <label class="field">
                <span>Kind</span>
                <select name="type">
                  {STAGE_TYPES.map(([value, text]) => (
                    <option key={value} value={value} selected={value === 'interview'}>
                      {text}
                    </option>
                  ))}
                </select>
              </label>
              <button class="btn btn-primary btn-small" type="submit">
                Add stage
              </button>
            </form>
          ) : null}
        </section>

        <section class="record-section" id="interview-plan">
          <h2>Interview plan</h2>
          <Mute>
            Feedback is written by the interviewers booked onto each interview. Missing feedback is flagged
            when a candidate moves on, and does not hold them.{' '}
            <a href={routes.settingsScorecards.index.href()}>Manage scorecards</a>
          </Mute>
          {editable.map((stage) => {
            let interviews = stage.interviews ?? []
            return (
              <details key={stage.key} class="plan-stage" open={interviews.length > 0}>
                <summary>
                  {stageLabel(stage, stage.key)}{' '}
                  <span class="tab-count">
                    {interviews.length} {interviews.length === 1 ? 'interview' : 'interviews'}
                  </span>
                </summary>
                {interviews.length === 0 ? (
                  <p class="sub">No interviews, so this stage expects no feedback.</p>
                ) : (
                  <ul class="queue">
                    {interviews.map((interview) => (
                      <li key={interview.key} class="queue-item">
                        <div class="body">
                          <span class="title">{interview.name ?? label(interview.key)}</span>
                          <span class="hint">
                            {interview.required === false ? 'Optional' : 'Required'}
                            {interview.duration_minutes ? ` · ${interview.duration_minutes} min` : ''}
                            {interview.rubric_key
                              ? ` · ${job.rubrics.find((row) => row.key === interview.rubric_key)?.name ?? label(interview.rubric_key)} scorecard`
                              : ' · Overall rating only'}
                          </span>
                        </div>
                        {canManage ? (
                          <form method="post" action={action}>
                            <input type="hidden" name="intent" value="pipeline" />
                            <input type="hidden" name="op" value="remove_interview" />
                            <input type="hidden" name="key" value={stage.key} />
                            <input type="hidden" name="interview_key" value={interview.key} />
                            <button
                              class="btn btn-ghost btn-small"
                              type="submit"
                              aria-label={`Remove ${interview.name ?? interview.key}`}
                            >
                              Remove
                            </button>
                          </form>
                        ) : null}
                      </li>
                    ))}
                  </ul>
                )}
                {canManage ? (
                  <form method="post" action={action} class="hub-bar" autocomplete="off">
                    <input type="hidden" name="intent" value="pipeline" />
                    <input type="hidden" name="op" value="add_interview" />
                    <input type="hidden" name="key" value={stage.key} />
                    <label class="field">
                      <span>Interview</span>
                      <input name="name" required maxLength={80} placeholder="e.g. Technical deep dive" />
                    </label>
                    <label class="field">
                      <span>Minutes</span>
                      <input name="duration_minutes" type="number" min="15" step="15" defaultValue="45" />
                    </label>
                    <label class="field">
                      <span>Scorecard</span>
                      <select name="rubric_key">
                        <option value="">Overall rating only</option>
                        {job.rubrics.map((rubric) => (
                          <option key={rubric.key} value={rubric.key}>
                            {rubric.name}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label class="field">
                      <span>Feedback</span>
                      <select name="required">
                        <option value="true">Required</option>
                        <option value="false">Optional</option>
                      </select>
                    </label>
                    <button class="btn btn-primary btn-small" type="submit">
                      Add interview
                    </button>
                  </form>
                ) : null}
              </details>
            )
          })}
        </section>

        <section class="record-section">
          <h2 id="hiring-team">Hiring team</h2>
          {job.hiringTeam.length === 0 ? (
            <EmptyState>
              No hiring team on this job yet. Add the people who will interview and decide.
            </EmptyState>
          ) : (
            <ul class="queue">
              {job.hiringTeam.map((member) => (
                <li key={member.id} class="queue-item">
                  <div class="body">
                    <span class="title">{member.name ?? 'Team member'}</span>
                    <span class="hint">{label(member.role)}</span>
                  </div>
                  {canManage ? (
                    <div class="row-actions">
                      <form method="post" action={action} class="inline-form">
                        <input type="hidden" name="intent" value="team_role" />
                        <input type="hidden" name="member_id" value={member.id} />
                        <label class="visually-hidden" for={`team-role-${member.id}`}>
                          Role for {member.name}
                        </label>
                        <select id={`team-role-${member.id}`} name="team_role">
                          {TEAM_ROLES.map(([value, text]) => (
                            <option
                              key={value}
                              value={value}
                              selected={value === member.role.replace('_', '-')}
                            >
                              {text}
                            </option>
                          ))}
                        </select>
                        <button class="btn btn-ghost btn-small" type="submit">
                          Change role
                        </button>
                      </form>
                      <form method="post" action={action}>
                        <input type="hidden" name="intent" value="team_remove" />
                        <input type="hidden" name="member_id" value={member.id} />
                        <button
                          class="btn btn-ghost btn-small"
                          type="submit"
                          aria-label={`Remove ${member.name ?? 'member'} from the team`}
                        >
                          Remove
                        </button>
                      </form>
                    </div>
                  ) : null}
                </li>
              ))}
            </ul>
          )}
          {canManage && job.assignableMembers.length > 0 ? (
            <form method="post" action={action} class="hub-bar">
              <input type="hidden" name="intent" value="team_add" />
              <label class="field">
                <span>Person</span>
                <select name="user_id" required>
                  <option value="">Choose a person</option>
                  {job.assignableMembers.map((member) => (
                    <option key={member.userId} value={member.userId}>
                      {member.name}
                    </option>
                  ))}
                </select>
              </label>
              <label class="field">
                <span>Role on this job</span>
                <select name="team_role" required>
                  {TEAM_ROLES.map(([value, text]) => (
                    <option key={value} value={value}>
                      {text}
                    </option>
                  ))}
                </select>
              </label>
              <button class="btn btn-primary btn-small" type="submit">
                Add to team
              </button>
            </form>
          ) : null}
        </section>

        <section class="record-section" id="careers">
          <h2>Careers sites</h2>
          <p class="sub">
            Choose where this role appears. Listings require an active, non-confidential job and a published
            posting.
          </p>
          {canManage ? (
            <form method="post" action={action} class="form-narrow">
              <input type="hidden" name="intent" value="careers" />
              <label class="field">
                <span>Audience</span>
                <select name="careers_visibility" aria-label="Audience">
                  {(['public', 'internal', 'both', 'hidden'] as const).map((value) => (
                    <option value={value} selected={value === (job.careersVisibility ?? 'public')}>
                      {label(value)}
                    </option>
                  ))}
                </select>
              </label>
              <label class="field">
                <span>Publication</span>
                <select name="careers_published" aria-label="Publication">
                  <option value="false" selected={!job.careersPublished}>
                    Unpublished
                  </option>
                  <option value="true" selected={job.careersPublished}>
                    Published
                  </option>
                </select>
              </label>
              <button class="btn btn-primary btn-small" type="submit">
                Save careers settings
              </button>
            </form>
          ) : (
            <p>
              {label(job.careersVisibility ?? 'public')} ·{' '}
              {job.careersPublished ? 'Published' : 'Unpublished'}
            </p>
          )}
          <p>
            <a href={`${routes.careersIndex.href()}${orgQuery}`}>Public careers</a> ·{' '}
            <a href={routes.internalCareers.href()}>Internal careers</a>
          </p>
        </section>

        <section class="record-section" id="openings">
          <h2>Openings</h2>
          <p>{typeof job.openings === 'number' ? openingsLabel(job.openings) : 'Openings not set.'}</p>
          {canManage ? (
            <form method="post" action={action} class="hub-bar">
              <input type="hidden" name="intent" value="openings" />
              <label class="field">
                <span>Headcount on this job</span>
                <input name="openings" type="number" min="0" defaultValue={job.openings ?? 1} />
              </label>
              <button class="btn btn-primary btn-small" type="submit">
                Save openings
              </button>
            </form>
          ) : null}
          {job.requisition ? (
            <p class="sub">
              Requisition {job.requisition.code} · {job.requisition.title} · {label(job.requisition.status)}
            </p>
          ) : (
            <p class="sub">No requisition linked.</p>
          )}
          <a href={`${routes.requisitions.index.href()}${orgQuery}`}>All openings</a>
        </section>
      </div>
    )
  }
}
