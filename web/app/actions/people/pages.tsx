import { PersonActivity, type MessagePreview, type PersonCrm } from './activity.tsx'
import { ApplicationShowPage } from '../applications/pages.tsx'
import type { ApplicationActionResult } from '../applications/controller.tsx'
import { candidateNextStep, type CandidateWorkspaceState } from '../../data/candidate-workspace.ts'
import type { Handle } from 'remix/component'
import { Frame } from 'remix/component'

import type {
  Affiliation,
  Application,
  Company,
  Enrollment,
  Person,
  Project,
  ProjectMember,
  SavedSearch,
  Sequence,
  TimelineEvent,
} from '../../data/api.ts'
import type { PersonCustomFieldsQuery } from '../../graphql/generated.ts'
import { label, statusTone } from '../../data/labels.ts'
import { routes } from '../../routes.ts'
import { FoldSectionTabs } from '../../ui/app-nav.tsx'
import { FilterSegments, ListPagination, SectionTabs } from '../../ui/page-chrome.tsx'
import { EmptyState, Field, Mute, PrimaryButton, RowLink, RowList, Shell } from '../../ui/shell.tsx'
import { signedIn } from '../../data/auth.ts'
import { recordHref, returnLabel } from '../../data/record-return.ts'
import { ResumeSection } from '../../ui/resume.tsx'
import type { PersonDocuments } from '../../data/documents.ts'
import { PersonTimelineFrame } from './timeline-frame.tsx'
import { personTabs, personWorkspaceHref, type PersonTab } from '../../data/person-workspace.ts'
import { stageLabel } from '../../data/board.ts'
import { ApplicationActions } from '../../ui/application-actions.tsx'

const WHO = [
  { id: '', label: 'Everyone' },
  { id: 'candidate', label: 'Candidates' },
  { id: 'prospect', label: 'Prospects' },
  { id: 'employee', label: 'Employees' },
] as const

const ADVANCED_FILTERS = ['tag', 'source', 'engagement_status', 'location', 'not_contacted_days'] as const
type PeopleFilters = {
  q?: string
  lifecycle_stage?: string
  project_id?: string
  tag?: string
  source?: string
  engagement_status?: string
  location?: string
  not_contacted_days?: string
}

function peopleQuery(orgQuery: string, filters: PeopleFilters, patch: Record<string, string>) {
  const params = new URLSearchParams(orgQuery.startsWith('?') ? orgQuery.slice(1) : '')
  const next = {
    q: filters.q ?? '',
    lifecycle_stage: filters.lifecycle_stage ?? '',
    project_id: filters.project_id ?? '',
    ...Object.fromEntries(ADVANCED_FILTERS.map((k) => [k, filters[k] ?? ''])),
    ...patch,
  }
  for (const [key, value] of Object.entries(next)) {
    if (value) params.set(key, value)
    else params.delete(key)
  }
  const text = params.toString()
  return `${routes.peopleIndex.href()}${text ? `?${text}` : ''}`
}

export type BulkSelection = { personIds: string[]; projectId?: string; sequenceId?: string }

export function PeopleIndexPage(
  handle: Handle<{
    people: Person[]
    sequences?: Sequence[]
    projects?: Project[]
    savedSearches?: SavedSearch[]
    filters?: PeopleFilters
    orgQuery: string
    notice?: string
    page?: number
    total?: number
    perPage?: number
    /** What the bulk form held when a bulk action failed, so the re-render keeps it. */
    bulk?: BulkSelection
  }>,
) {
  return () => {
    let {
      bulk,
      page = 1,
      total,
      perPage = 50,
      people,
      sequences = [],
      projects = [],
      savedSearches = [],
      filters = {},
      orgQuery,
      notice,
    } = handle.props
    let filtered = Boolean(
      filters.q || filters.lifecycle_stage || filters.project_id || ADVANCED_FILTERS.some((k) => filters[k]),
    )
    let action = `${routes.peopleList.href()}${orgQuery}`
    const permissions = signedIn()?.permissions ?? []
    const canBulk = permissions.includes('person.update')
    const canEnroll = canBulk && permissions.includes('sequence.enroll')
    const canPool = canBulk && permissions.includes('project.manage')
    const returnTo = peopleQuery(orgQuery, filters, {})
    return (
      <Shell title="People" eyebrow="CRM" orgQuery={orgQuery}>
        <FoldSectionTabs label="People sections" parent="people" orgQuery={orgQuery} />
        <div class="list-workspace">
          <p class="list-count">
            {typeof total === 'number'
              ? `${total} ${total === 1 ? 'person' : 'people'}${filtered ? ' match' : ''} · ${people.length} shown on this page, newest first`
              : `${people.length} ${people.length === 1 ? 'person' : 'people'} shown`}
            {filtered && typeof total !== 'number' ? ' · filtered results' : ''}
            {people.some((p) => p.visibility === 'restricted') ? ' · includes restricted records' : ''}
          </p>
          {notice ? (
            notice.startsWith('Could not complete') ? (
              <p class="notice-bad" role="alert">
                {notice}
              </p>
            ) : (
              <p class="notice" role="status">
                {notice}
              </p>
            )
          ) : null}

          <FilterSegments
            label="Who"
            links={WHO.map((who) => ({
              href: peopleQuery(orgQuery, filters, { lifecycle_stage: who.id }),
              label: who.label,
              current: (!filters.lifecycle_stage && who.id === '') || filters.lifecycle_stage === who.id,
            }))}
          />
          <form
            class="list-filters people-filters"
            method="get"
            action={routes.peopleIndex.href()}
            role="search"
            aria-label="Find people"
          >
            {orgQuery.includes('slug=') ? (
              <input
                type="hidden"
                name="slug"
                value={new URLSearchParams(orgQuery.slice(1)).get('slug') ?? ''}
              />
            ) : null}
            {filters.lifecycle_stage ? (
              <input type="hidden" name="lifecycle_stage" value={filters.lifecycle_stage} />
            ) : null}
            <label class="field list-query">
              <span>Search people</span>
              <input type="search" name="q" defaultValue={filters.q ?? ''} />
            </label>
            {projects.length ? (
              <label class="field">
                <span>Filter by pool</span>
                <select name="project_id">
                  <option value="">All pools</option>
                  {projects.map((project) => (
                    <option key={project.id} value={project.id} selected={filters.project_id === project.id}>
                      {project.name}
                    </option>
                  ))}
                </select>
              </label>
            ) : filters.project_id ? (
              <input type="hidden" name="project_id" value={filters.project_id} />
            ) : null}
            <PrimaryButton type="submit">Search people</PrimaryButton>
            {filtered ? (
              <a class="btn btn-ghost" href={peopleQuery(orgQuery, {}, {})}>
                Clear filters
              </a>
            ) : null}
            <details class="people-filters-more" open={ADVANCED_FILTERS.some((key) => Boolean(filters[key]))}>
              <summary>More filters</summary>
              <div class="list-filters people-filters-advanced">
                <label class="field">
                  <span>Tag</span>
                  <input type="text" name="tag" defaultValue={filters.tag ?? ''} placeholder="go, infra" />
                </label>
                <label class="field">
                  <span>Location</span>
                  <input type="text" name="location" defaultValue={filters.location ?? ''} />
                </label>
                <label class="field">
                  <span>Source</span>
                  <select name="source">
                    <option value="">Any source</option>
                    {['sourced', 'referral', 'applied', 'event', 'import', 'agent'].map((value) => (
                      <option key={value} value={value} selected={filters.source === value}>
                        {label(value)}
                      </option>
                    ))}
                  </select>
                </label>
                <label class="field">
                  <span>Engagement</span>
                  <select name="engagement_status">
                    <option value="">Any engagement</option>
                    {[
                      'not_contacted',
                      'contacted',
                      'replied',
                      'interested',
                      'not_interested',
                      'do_not_contact',
                    ].map((value) => (
                      <option key={value} value={value} selected={filters.engagement_status === value}>
                        {label(value)}
                      </option>
                    ))}
                  </select>
                </label>
                <label class="field">
                  <span>Not contacted in (days)</span>
                  <input
                    type="number"
                    name="not_contacted_days"
                    min="1"
                    defaultValue={filters.not_contacted_days ?? ''}
                  />
                </label>
              </div>
            </details>
          </form>

          {savedSearches.length > 0 ? (
            <FilterSegments
              label="Saved searches"
              links={savedSearches.map((search) => ({
                href: peopleQuery(orgQuery, {}, search.filters ?? {}),
                label: search.name,
              }))}
            />
          ) : null}
          <details class="list-save">
            <summary>Save this search</summary>
            <form method="post" action={action} class="list-filters">
              <input type="hidden" name="intent" value="save_search" />
              <input type="hidden" name="q" value={filters.q ?? ''} />
              <input type="hidden" name="lifecycle_stage" value={filters.lifecycle_stage ?? ''} />
              <input type="hidden" name="project_id" value={filters.project_id ?? ''} />
              {ADVANCED_FILTERS.map((k) => (
                <input key={k} type="hidden" name={k} value={filters[k] ?? ''} />
              ))}
              <Field label="Save this search" name="name" />
              <button class="btn btn-ghost btn-small" type="submit">
                Save search
              </button>
            </form>
          </details>

          {people.length === 0 ? (
            <EmptyState>
              {filtered ? (
                <>
                  No one matches these filters. <a href={peopleQuery(orgQuery, {}, {})}>Clear filters</a> or{' '}
                  {permissions.includes('person.create') ? (
                    <a href={`${routes.peopleCreate.index.href()}${orgQuery}`}>add a person</a>
                  ) : (
                    'try another search'
                  )}
                  .
                </>
              ) : (
                <>
                  No people visible for this actor. Sign in as admin or recruiter, or check membership scopes.
                </>
              )}
            </EmptyState>
          ) : (
            <form method="post" action={action}>
              <input type="hidden" name="q" value={filters.q ?? ''} />
              <input type="hidden" name="lifecycle_stage" value={filters.lifecycle_stage ?? ''} />
              <input type="hidden" name="project_id" value={filters.project_id ?? ''} />
              {ADVANCED_FILTERS.map((k) => (
                <input key={k} type="hidden" name={k} value={filters[k] ?? ''} />
              ))}
              {canBulk ? (
                <div class="list-filters bulk-actions" role="group" aria-label="Actions for selected people">
                  {canEnroll ? (
                    <>
                      <label class="field">
                        <span>Bulk sequence</span>
                        <select name="sequence_id">
                          <option value="">Choose sequence</option>
                          {sequences.map((s) => (
                            <option key={s.id} value={s.id} selected={bulk?.sequenceId === s.id}>
                              {s.name}
                              {s.is_template ? ' (template)' : ''}
                            </option>
                          ))}
                        </select>
                      </label>
                      <button
                        class="btn btn-primary btn-small"
                        type="submit"
                        name="intent"
                        value="bulk_enroll"
                      >
                        Review and enroll
                      </button>
                    </>
                  ) : null}
                  {canPool && projects.length > 0 ? (
                    <>
                      <label class="field">
                        <span>Pool to add selected to</span>
                        <select name="bulk_project_id">
                          <option value="">Choose pool</option>
                          {projects.map((project) => (
                            <option
                              key={project.id}
                              value={project.id}
                              selected={bulk?.projectId === project.id}
                            >
                              {project.name}
                            </option>
                          ))}
                        </select>
                      </label>
                      <button class="btn btn-ghost btn-small" type="submit" name="intent" value="bulk_pool">
                        Add selected to pool
                      </button>
                    </>
                  ) : null}
                  <button class="btn btn-ghost btn-small" type="submit" name="intent" value="bulk_dnc">
                    Mark do not contact
                  </button>
                  <span class="list-meta">Select rows below to apply an action.</span>
                </div>
              ) : null}
              <div class="table-wrap" role="region" aria-label="People results" tabIndex={0}>
                <table class="table">
                  <thead>
                    <tr>
                      {canBulk ? (
                        <th scope="col">
                          <span class="visually-hidden">Select</span>
                        </th>
                      ) : null}
                      <th>Person</th>
                      <th>Hiring</th>
                      <th>Owner</th>
                    </tr>
                  </thead>
                  <tbody>
                    {people.map((person) => (
                      <tr key={person.id}>
                        {canBulk ? (
                          <td class="selection-cell">
                            <input
                              type="checkbox"
                              name="person_id"
                              value={person.id}
                              checked={bulk?.personIds.includes(person.id) ?? false}
                              aria-label={`Select ${person.display_name}`}
                            />
                          </td>
                        ) : null}
                        <td>
                          <a
                            href={recordHref(
                              routes.peopleShow.index.href({ personId: person.id }),
                              orgQuery,
                              returnTo,
                            )}
                          >
                            {person.display_name}
                          </a>
                          {person.primary_email ? <div class="list-meta">{person.primary_email}</div> : null}
                        </td>
                        <td>
                          <span class="chip">{label(person.lifecycle_stage ?? 'unknown')}</span>
                          {person.do_not_contact ? <span class="chip chip-bad">Do not contact</span> : null}
                          {person.visibility === 'restricted' ? (
                            <span class="chip chip-warn">Restricted</span>
                          ) : null}
                        </td>
                        <td>{person.owner?.name || person.owner?.email || '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </form>
          )}
          {typeof total === 'number' && total > perPage ? (
            <ListPagination
              page={page}
              pages={Math.ceil(total / perPage)}
              prevHref={page > 1 ? peopleQuery(orgQuery, filters, { page: String(page - 1) }) : undefined}
              nextHref={
                page * perPage < total
                  ? peopleQuery(orgQuery, filters, { page: String(page + 1) })
                  : undefined
              }
            />
          ) : null}
        </div>
      </Shell>
    )
  }
}

export function PersonCreatePage(handle: Handle<{ orgQuery: string; notice?: string }>) {
  return () => {
    let { orgQuery, notice } = handle.props
    return (
      <Shell title="New person" eyebrow="People" orgQuery={orgQuery}>
        <FoldSectionTabs label="People sections" parent="people" orgQuery={orgQuery} />
        {notice ? (
          <p class="notice" role="alert">
            {notice}
          </p>
        ) : null}
        <form method="post" action={`${routes.peopleCreate.action.href()}${orgQuery}`} class="form-narrow">
          <input type="hidden" name="intent" value="create" />
          <Field label="Full name" name="display_name" required />
          <Field label="Email" name="email" email />
          <PrimaryButton type="submit">Create person</PrimaryButton>
        </form>
      </Shell>
    )
  }
}

export function PersonShowPage(
  handle: Handle<{
    person: Person
    applications: Application[]
    openJobs?: Array<{ id: string; title: string }>
    memberships: ProjectMember[]
    enrollments: Enrollment[]
    affiliations: Affiliation[]
    companies: Company[]
    timeline: TimelineEvent[]
    workspaces?: Record<string, CandidateWorkspaceState>
    activeApplicationId?: string
    workflowResult?: ApplicationActionResult
    editValues?: Record<string, string>
    tab?: PersonTab
    applicationReasons?: Record<string, string>
    actionIntent?: string
    toStageKey?: string
    archiveReasonKey?: string
    returnTo?: string
    documents?: PersonDocuments
    customFields?: PersonCustomFieldsQuery extends { person: infer P }
      ? P extends { customFields: infer C }
        ? C
        : never
      : never
    orgQuery: string
    notice?: string
    error?: string
    crm?: PersonCrm
    preview?: MessagePreview
    draft?: Record<string, string>
  }>,
) {
  return () => {
    const {
      person,
      applications,
      memberships,
      enrollments,
      affiliations,
      companies,
      timeline,
      orgQuery,
      notice,
      error,
    } = handle.props
    const permissions = signedIn()?.permissions ?? []
    const canReadApplications = permissions.includes('application.read')
    const tabs = personTabs
      .filter((tab) => tab.id !== 'resume' || handle.props.documents?.status !== 'omitted')
      .filter((tab) => tab.id !== 'applications' || canReadApplications)
    const selectedTab = tabs.some((tab) => tab.id === handle.props.tab)
      ? handle.props.tab!
      : canReadApplications
        ? 'applications'
        : 'details'
    const returnTo = handle.props.returnTo ?? `${routes.peopleIndex.href()}${orgQuery}`
    const action = personWorkspaceHref(person.id, orgQuery, handle.props.returnTo, selectedTab)
    return (
      <Shell
        title={person.display_name}
        titleActions={
          <ApplicationActions
            applications={applications}
            actionFor={() => personWorkspaceHref(person.id, orgQuery, handle.props.returnTo, 'applications')}
            error={Boolean(error) && handle.props.actionIntent === 'transition'}
            archiveError={Boolean(error) && handle.props.actionIntent === 'archive'}
            archiveReasonKey={handle.props.archiveReasonKey}
            toStageKey={handle.props.toStageKey}
            allowHire
          />
        }
        eyebrow="Person"
        sub={person.primary_email ?? undefined}
        orgQuery={orgQuery}
        backHref={returnTo}
        backLabel={returnLabel(returnTo)}
      >
        <div class="record-workspace person-workspace">
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
          <SectionTabs
            className="record-section-tabs"
            label="Person sections"
            links={tabs.map((tab) => ({
              href: personWorkspaceHref(person.id, orgQuery, handle.props.returnTo, tab.id),
              label: tab.label,
              current: selectedTab === tab.id,
              count: tab.id === 'applications' ? applications.length : undefined,
            }))}
          />
          {selectedTab === 'applications' ? (
            <section class="record-section person-application-history" aria-label="Application history">
              <h2>
                Application history <span class="section-count">{applications.length} shown</span>
              </h2>
              {applications.length ? (
                <ul class="person-applications">
                  {applications.map((app) => {
                    const workspace = handle.props.workspaces?.[app.id]
                    const stages = app.pipeline?.stages ?? []
                    const index = stages.findIndex((stage) => stage.key === app.current_stage_key)
                    const current = stages[index]
                    return (
                      <li key={app.id} class="person-application">
                        <div class="person-application-heading">
                          <div>
                            <a
                              class="person-application-title"
                              href={recordHref(
                                routes.applicationsShow.index.href({ applicationId: app.id }),
                                orgQuery,
                                handle.props.returnTo ?? returnTo,
                              )}
                            >
                              {app.job?.title ?? app.job_id}
                            </a>
                            <p class="list-meta">
                              {stageLabel(current, app.current_stage_key ?? 'No stage')}
                              {index >= 0 ? ` · Stage ${index + 1} of ${stages.length}` : ''}
                            </p>
                          </div>
                          <span class={statusTone(app.status)}>
                            {['rejected', 'withdrawn'].includes(app.status)
                              ? `Archived · ${label(app.status)}`
                              : label(app.status)}
                          </span>
                        </div>
                        {handle.props.applicationReasons?.[app.id] ? (
                          <p class="list-meta">Reason: {handle.props.applicationReasons[app.id]}</p>
                        ) : null}
                        {stages.length ? (
                          <ol
                            class="person-stage-track"
                            aria-label={`${app.job?.title ?? 'Application'} pipeline`}
                          >
                            {stages.map((stage, stageIndex) => (
                              <li
                                key={stage.key}
                                aria-current={
                                  app.status === 'active' && index === stageIndex ? 'step' : undefined
                                }
                                data-complete={index > stageIndex ? 'true' : undefined}
                              >
                                <span class="person-stage-marker" aria-hidden="true" />
                                {stageLabel(stage, stage.key)}
                              </li>
                            ))}
                          </ol>
                        ) : null}
                        {workspace?.status === 'ready' ? (
                          <>
                            <div class="candidate-next-step">
                              <span class="list-meta">Next step</span>
                              <p>{candidateNextStep(workspace.data)}</p>
                            </div>
                            <details
                              class="candidate-workflow"
                              open={app.status === 'active' || handle.props.activeApplicationId === app.id}
                            >
                              <summary>Interviews, feedback and offers</summary>
                              <ApplicationShowPage
                                {...workspace.data}
                                embedded
                                orgQuery={orgQuery}
                                returnTo={handle.props.returnTo}
                                actionHref={personWorkspaceHref(
                                  person.id,
                                  orgQuery,
                                  handle.props.returnTo,
                                  'applications',
                                )}
                                {...(handle.props.activeApplicationId === app.id
                                  ? handle.props.workflowResult
                                  : {})}
                              />
                            </details>
                          </>
                        ) : workspace?.status === 'failed' ? (
                          <p class="notice-bad" role="status">
                            Candidate workflow could not load. Refresh to try again.
                          </p>
                        ) : null}
                      </li>
                    )
                  })}
                </ul>
              ) : (
                <Mute>No applications yet.</Mute>
              )}
              {(handle.props.openJobs ?? []).length ? (
                <form method="post" action={action} class="hub-bar">
                  <input type="hidden" name="intent" value="add_to_job" />
                  <label class="field">
                    <span>Add to a job</span>
                    <select name="job_id" required>
                      <option value="">Choose a job</option>
                      {(handle.props.openJobs ?? []).map((job) => (
                        <option key={job.id} value={job.id}>
                          {job.title}
                        </option>
                      ))}
                    </select>
                  </label>
                  <button class="btn btn-primary btn-small" type="submit">
                    Add to job
                  </button>
                  <p class="sub">
                    Lists open jobs only. Jobs where they already have an active application are left out.
                  </p>
                </form>
              ) : null}
            </section>
          ) : null}
          {selectedTab === 'resume' ? (
            <ResumeSection
              personId={person.id}
              documents={handle.props.documents}
              orgQuery={orgQuery}
              expanded
              uploadAction={action}
            />
          ) : null}
          {selectedTab === 'activity' ? (
            <div class="stack">
              {handle.props.crm ? (
                <PersonActivity
                  person={person}
                  crm={handle.props.crm}
                  action={action}
                  permissions={permissions}
                  orgQuery={orgQuery}
                  preview={handle.props.preview}
                  draft={handle.props.draft}
                />
              ) : null}
              <section class="record-section" aria-label="Timeline">
                <h2>Change history</h2>
                <Frame
                  src={`${routes.peopleTimeline.href({ personId: person.id })}${orgQuery}`}
                  fallback={<PersonTimelineFrame events={timeline} />}
                />
              </section>
              {permissions.includes('communication.send') && !handle.props.crm ? (
                <details class="record-section" open={Boolean(error)}>
                  <summary>Send a message</summary>
                  <form method="post" action={action} class="form-narrow">
                    <input type="hidden" name="intent" value="message" />
                    <Field label="Subject" name="subject" required />
                    <label class="field">
                      <span>Body</span>
                      <textarea name="body" rows={5} required />
                    </label>
                    <PrimaryButton type="submit">Send email</PrimaryButton>
                  </form>
                </details>
              ) : null}
            </div>
          ) : null}
          {selectedTab === 'details' ? (
            <div class="stack">
              {permissions.includes('person.update') || permissions.includes('person.edit_details') ? (
                <details
                  class="record-section profile-edit"
                  open={Boolean(error) && handle.props.actionIntent === 'edit_details'}
                >
                  <summary class="btn btn-ghost">Edit details</summary>
                  <form method="post" action={action} class="profile-edit-form">
                    <input type="hidden" name="intent" value="edit_details" />
                    <Field
                      label="Full name"
                      name="display_name"
                      required
                      defaultValue={
                        handle.props.actionIntent === 'edit_details'
                          ? handle.props.editValues?.display_name
                          : person.display_name
                      }
                    />
                    <Field
                      label="Email"
                      name="email"
                      email
                      defaultValue={
                        handle.props.actionIntent === 'edit_details'
                          ? handle.props.editValues?.email
                          : (person.primary_email ?? '')
                      }
                    />
                    <Field
                      label="Phone"
                      name="phone"
                      defaultValue={
                        handle.props.actionIntent === 'edit_details'
                          ? handle.props.editValues?.phone
                          : (person.primary_phone ?? '')
                      }
                    />
                    <button class="btn btn-primary" type="submit">
                      Save details
                    </button>
                  </form>
                </details>
              ) : null}
              <dl class="record-summary" aria-label="Contact details">
                <Meta label="Email" value={person.primary_email ?? '—'} />
                <Meta label="Phone" value={person.primary_phone ?? '—'} />
                <Meta label="Lifecycle" value={person.lifecycle_stage ?? '—'} />
                <Meta label="Visibility" value={person.visibility ?? '—'} />
              </dl>
              <div class="record-columns">
                <div class="stack">
                  <section class="record-section" aria-label="Details">
                    <h2>Details</h2>
                    {handle.props.customFields?.length ? (
                      <dl class="record-fields" aria-label="Custom fields">
                        {handle.props.customFields.map((field) => (
                          <div key={field.key}>
                            <dt>{field.definition.label}</dt>
                            <dd>{formatCustomValue(field)}</dd>
                          </div>
                        ))}
                      </dl>
                    ) : (
                      <Mute>No custom details.</Mute>
                    )}
                  </section>
                </div>
                <div class="stack">
                  <section class="record-section" aria-label="Companies">
                    <h2>Companies</h2>
                    {affiliations.length ? (
                      <ul class="record-rows">
                        {affiliations.map((a) => (
                          <li key={a.id}>
                            <strong>{a.company?.name ?? a.company_id}</strong>
                            <span class="list-meta">{a.title ?? '—'}</span>
                            {permissions.includes('person.update') ||
                            permissions.includes('person.edit_details') ? (
                              <details
                                open={
                                  Boolean(error) &&
                                  handle.props.actionIntent === 'edit_company' &&
                                  handle.props.editValues?.affiliation_id === a.id
                                }
                              >
                                <summary>Edit company</summary>
                                <form method="post" action={action} class="form-narrow">
                                  <input type="hidden" name="intent" value="edit_company" />
                                  <input type="hidden" name="affiliation_id" value={a.id} />
                                  <label class="field">
                                    <span>Company</span>
                                    <select name="company_id" aria-label="Company" required>
                                      {companies.map((company) => (
                                        <option
                                          key={company.id}
                                          value={company.id}
                                          selected={
                                            company.id ===
                                            (handle.props.editValues?.affiliation_id === a.id
                                              ? handle.props.editValues?.company_id
                                              : a.company_id)
                                          }
                                        >
                                          {company.name}
                                        </option>
                                      ))}
                                    </select>
                                  </label>
                                  <label class="field">
                                    <span>Title</span>
                                    <input
                                      name="title"
                                      defaultValue={
                                        handle.props.editValues?.affiliation_id === a.id
                                          ? handle.props.editValues?.title
                                          : (a.title ?? '')
                                      }
                                    />
                                  </label>
                                  <button class="btn btn-primary" type="submit">
                                    Save company
                                  </button>
                                </form>
                              </details>
                            ) : null}
                          </li>
                        ))}
                      </ul>
                    ) : (
                      <Mute>No company affiliations.</Mute>
                    )}
                    {(permissions.includes('person.update') || permissions.includes('person.edit_details')) &&
                    companies.length ? (
                      <details>
                        <summary>Link a company</summary>
                        <form method="post" action={action} class="form-narrow">
                          <input type="hidden" name="intent" value="edit_company" />
                          <label class="field">
                            <span>Company</span>
                            <select name="company_id" required>
                              {companies.map((company) => (
                                <option key={company.id} value={company.id}>
                                  {company.name}
                                </option>
                              ))}
                            </select>
                          </label>
                          <Field label="Title" name="title" />
                          <PrimaryButton type="submit">Link company</PrimaryButton>
                        </form>
                      </details>
                    ) : null}
                  </section>
                  {permissions.includes('project.read') ? (
                    <section class="record-section" aria-label="Pools">
                      <h2>Pools</h2>
                      {memberships.length ? (
                        <RowList>
                          {memberships.map((member) => (
                            <RowLink
                              key={member.id}
                              href={`${routes.poolMembersShow.index.href({ memberId: member.id })}${orgQuery}`}
                              title={member.project?.name ?? member.project_id}
                              meta={`${label(member.status)} · ${label(member.current_stage_key)}`}
                            />
                          ))}
                        </RowList>
                      ) : (
                        <Mute>Not in any sourcing pool.</Mute>
                      )}
                    </section>
                  ) : null}
                  {permissions.includes('sequence.read') ? (
                    <section class="record-section" aria-label="Sequences">
                      <h2>Sequences</h2>
                      {enrollments.length ? (
                        <ul class="record-rows">
                          {enrollments.map((enrollment) => (
                            <li key={enrollment.id}>
                              <strong>{enrollment.sequence?.name ?? enrollment.sequence_id}</strong>
                              <span class="list-meta">
                                {label(enrollment.status)}
                                {enrollment.stop_reason ? ` · ${enrollment.stop_reason}` : ''}
                              </span>
                            </li>
                          ))}
                        </ul>
                      ) : (
                        <Mute>
                          No enrollments.{' '}
                          {permissions.includes('sequence.enroll') ? (
                            <a href={`${routes.sequencesIndex.href()}${orgQuery}`}>Enroll from Sequences</a>
                          ) : null}
                        </Mute>
                      )}
                    </section>
                  ) : null}
                </div>
              </div>
              {signedIn()?.roleKey === 'owner' && permissions.includes('person.erase') ? (
                <details class="record-section record-danger">
                  <summary>Erase personal data</summary>
                  <form method="post" action={action} class="form-narrow">
                    <input type="hidden" name="intent" value="erase" />
                    <Mute>
                      Permanently erases personal data. Application archiving keeps this person record.
                    </Mute>
                    <button class="btn btn-ghost" type="submit">
                      Erase person
                    </button>
                  </form>
                </details>
              ) : null}
            </div>
          ) : null}
        </div>
      </Shell>
    )
  }
}

function Meta(handle: Handle<{ label: string; value: string }>) {
  return () => (
    <div>
      <dt>{handle.props.label}</dt>
      <dd>{handle.props.value}</dd>
    </div>
  )
}

type CustomFieldRow = NonNullable<PersonCustomFieldsQuery['person']>['customFields'][number]

function formatCustomValue(field: CustomFieldRow): string {
  const value = field as Record<string, unknown>
  for (const key of ['text', 'number', 'date', 'option', 'referenceId'] as const) {
    if (value[key] !== undefined && value[key] !== null) return String(value[key])
  }
  if (typeof value.boolean === 'boolean') return value.boolean ? 'Yes' : 'No'
  if (Array.isArray(value.options)) return value.options.join(', ')
  return '—'
}
