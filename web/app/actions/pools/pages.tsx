import type { Handle } from 'remix/component'
import { css } from 'remix/component'
import { signedIn } from '../../data/auth.ts'

import type {
  Job,
  Person,
  Project,
  ProjectMember,
  SavedSearch,
  Sequence,
  StageTransition,
} from '../../data/api.ts'
import { routes } from '../../routes.ts'
import { FoldSectionTabs } from '../../ui/app-nav.tsx'
import { DragMove } from '../../ui/public/drag-move.tsx'
import { Field, Mute, PrimaryButton, RowLink, RowList, Shell } from '../../ui/shell.tsx'
import { label } from '../../data/labels.ts'

export function PoolsIndexPage(
  handle: Handle<{ projects: Project[]; jobs: Job[]; orgQuery: string; notice?: string }>,
) {
  return () => {
    let { projects, orgQuery, notice } = handle.props
    return (
      <Shell title="Pools" eyebrow="Sourcing" orgQuery={orgQuery}>
        <FoldSectionTabs label="People sections" parent="people" orgQuery={orgQuery} />
        <Mute>
          {projects.length} talent pool{projects.length === 1 ? '' : 's'} shown — prospects before a job
          application
        </Mute>
        {notice ? <p class="notice">{notice}</p> : null}
        <div class="table-wrap" role="region" aria-label="Talent pools results" tabIndex={0}>
          <table class="table">
            <thead>
              <tr>
                <th>Pool</th>
                <th>Feeds</th>
                <th>Active</th>
              </tr>
            </thead>
            <tbody>
              {projects.map((project) => (
                <tr key={project.id}>
                  <td>
                    <a href={`${routes.poolsShow.index.href({ projectId: project.id })}${orgQuery}`}>
                      {project.name}
                    </a>
                  </td>
                  <td>{project.job?.title ?? '—'}</td>
                  <td>{project.member_count ?? 0}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Shell>
    )
  }
}

export function PoolCreatePage(
  handle: Handle<{ jobs: Job[]; orgQuery: string; notice?: string; initialName?: string }>,
) {
  return () => {
    let { jobs, orgQuery, notice } = handle.props
    return (
      <Shell
        title="New talent pool"
        eyebrow="People"
        orgQuery={orgQuery}
        backHref={`${routes.poolsIndex.href()}${orgQuery}`}
        backLabel="Pools"
      >
        <FoldSectionTabs label="People sections" parent="people" orgQuery={orgQuery} />
        <Mute>Prospects before a job application.</Mute>
        {notice ? (
          <p class="notice" role="alert">
            {notice}
          </p>
        ) : null}
        <form method="post" action={`${routes.poolsCreate.action.href()}${orgQuery}`} class="form-narrow">
          <Field label="Name" name="name" defaultValue={handle.props.initialName} required />
          <label class="field">
            <span>Linked job (optional)</span>
            <select name="job_id">
              <option value="">None</option>
              {jobs.map((job) => (
                <option key={job.id} value={job.id}>
                  {job.title}
                </option>
              ))}
            </select>
          </label>
          <div class="form-actions">
            <PrimaryButton type="submit">Create pool</PrimaryButton>
            <a class="btn btn-ghost" href={`${routes.poolsIndex.href()}${orgQuery}`}>
              Cancel
            </a>
          </div>
        </form>
      </Shell>
    )
  }
}

export function PoolShowPage(
  handle: Handle<{
    project: Project
    members: ProjectMember[]
    people: Person[]
    savedSearches?: SavedSearch[]
    jobs?: Job[]
    sequences?: Sequence[]
    orgQuery: string
    notice?: string
    error?: string
  }>,
) {
  return () => {
    let {
      project,
      members,
      people,
      savedSearches = [],
      jobs = [],
      sequences = [],
      orgQuery,
      notice,
      error,
    } = handle.props
    let stages = project.pipeline?.stages?.length
      ? project.pipeline.stages
      : [
          { key: 'prospect', name: 'Prospect' },
          { key: 'reached-out', name: 'Reached out' },
          { key: 'replied', name: 'Replied' },
          { key: 'ready', name: 'Ready' },
        ]
    let active = members.filter((m) => m.status === 'active')
    let other = members.filter((m) => m.status !== 'active')
    let memberPersonIds = new Set(members.map((m) => m.person_id))
    let addable = people.filter((p) => !memberPersonIds.has(p.id))
    let action = `${routes.poolsShow.action.href({ projectId: project.id })}${orgQuery}`
    let canMove = signedIn()?.permissions?.includes('project.manage') ?? false
    let canEnroll = (signedIn()?.permissions?.includes('sequence.enroll') ?? false) && sequences.length > 0
    let canPick = active.length > 0 && (canMove || canEnroll)

    return (
      <Shell
        title={project.name}
        eyebrow="Pool"
        orgQuery={orgQuery}
        wide
        backHref={`${routes.poolsIndex.href()}${orgQuery}`}
        backLabel="Pools"
      >
        <Mute>
          {project.job?.title ? `Feeds ${project.job.title}` : 'No linked job'}
          {project.pipeline?.stages?.length ? ` · ${project.pipeline.stages.length} sourcing stages` : ''}
        </Mute>
        {notice ? (
          <p mix={css({ color: 'var(--bb-accent)', fontWeight: 600, marginBottom: '16px' })}>{notice}</p>
        ) : null}
        {error ? (
          <p role="alert" mix={css({ color: 'var(--bb-danger)', marginBottom: '16px' })}>
            {error}
          </p>
        ) : null}

        {signedIn()?.permissions?.includes('project.manage') ? (
          <details class="record-section workflow-disclosure">
            <summary>Add many at once</summary>
            <div class="stack">
              {project.saved_search_id ? (
                <form method="post" action={action} class="row-actions">
                  <input type="hidden" name="intent" value="refresh_smart" />
                  <button class="btn btn-ghost" type="submit">
                    Refresh from this pool’s saved search
                  </button>
                </form>
              ) : null}
              {savedSearches.length > 0 ? (
                <form method="post" action={action} class="hub-bar">
                  <input type="hidden" name="intent" value="add_saved_search" />
                  <label class="field">
                    <span>From a saved search</span>
                    <select name="saved_search_id" required>
                      <option value="">Choose a search</option>
                      {savedSearches.map((search) => (
                        <option key={search.id} value={search.id}>
                          {search.name}
                        </option>
                      ))}
                    </select>
                  </label>
                  <PrimaryButton type="submit">Add everyone it finds</PrimaryButton>
                </form>
              ) : null}
              {jobs.length > 0 ? (
                <form method="post" action={action} class="hub-bar">
                  <input type="hidden" name="intent" value="add_from_job" />
                  <label class="field">
                    <span>Past applicants of a job (rejected or withdrawn)</span>
                    <select name="job_id" required>
                      <option value="">Choose a job</option>
                      {jobs.map((job) => (
                        <option key={job.id} value={job.id}>
                          {job.title}
                        </option>
                      ))}
                    </select>
                  </label>
                  <PrimaryButton type="submit">Add past applicants</PrimaryButton>
                </form>
              ) : null}
            </div>
          </details>
        ) : null}

        {signedIn()?.permissions?.includes('project.manage') ? (
          <details class="record-section workflow-disclosure">
            <summary>Add to pool</summary>{' '}
            <form
              method="post"
              action={action}
              mix={css({
                maxWidth: '28rem',
                marginBottom: '28px',
                paddingBottom: '24px',
                borderBottom: '1px solid var(--bb-border)',
              })}
            >
              <input type="hidden" name="intent" value="add_member" />
              <label
                class="field"
                mix={css({ display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '16px' })}
              >
                <span mix={css({ fontSize: '13px', fontWeight: 500, color: 'var(--bb-text-muted)' })}>
                  Person
                </span>
                <select name="person_id" aria-label="Person" required>
                  <option value="">Select…</option>
                  {addable.map((person) => (
                    <option key={person.id} value={person.id}>
                      {person.display_name}
                      {person.lifecycle_stage ? ` · ${label(person.lifecycle_stage)}` : ''}
                    </option>
                  ))}
                </select>
              </label>
              <PrimaryButton type="submit">Add member</PrimaryButton>
            </form>
          </details>
        ) : null}
        <h2 mix={css({ fontSize: '18px', margin: '8px 0 16px' })}>Sourcing board</h2>
        <p class="sub mute">
          {canMove
            ? 'Drag a prospect to another stage, check several to move or enroll them together, or open one to review.'
            : 'Select a prospect to review them.'}
          {stages.length > 4 ? ' Scroll sideways for more stages.' : ''}
        </p>
        {canPick ? (
          <form
            id="pool-bulk"
            method="post"
            action={action}
            class="list-filters bulk-actions"
            aria-label="Actions for checked prospects"
          >
            {canMove ? (
              <>
                <label class="field">
                  <span>Move checked to</span>
                  <select name="to_stage_key">
                    <option value="">Choose stage</option>
                    {stages.map((stage) => (
                      <option key={stage.key} value={stage.key}>
                        {stage.name ?? label(stage.key)}
                      </option>
                    ))}
                  </select>
                </label>
                <button class="btn btn-ghost btn-small" type="submit" name="intent" value="bulk_move">
                  Move checked
                </button>
              </>
            ) : null}
            {canEnroll ? (
              <>
                <label class="field">
                  <span>Enroll checked in</span>
                  <select name="sequence_id">
                    <option value="">Choose sequence</option>
                    {sequences.map((sequence) => (
                      <option key={sequence.id} value={sequence.id}>
                        {sequence.name}
                      </option>
                    ))}
                  </select>
                </label>
                <button class="btn btn-primary btn-small" type="submit" name="intent" value="bulk_enroll">
                  Review and enroll
                </button>
              </>
            ) : null}
            <span class="list-meta">Check prospects on the board to act on several at once.</span>
          </form>
        ) : null}
        <div
          class="board pool-board"
          role="region"
          aria-label="Sourcing stages"
          tabIndex={0}
          data-drag-root={canMove ? 'board' : undefined}
        >
          {canMove ? (
            <form method="post" action={action} data-drag-form hidden>
              <input type="hidden" name="intent" value="move_member" />
              <input type="hidden" name="drag_id" />
              <input type="hidden" name="drag_to" />
            </form>
          ) : null}
          {canMove ? <DragMove /> : null}
          {stages.map((stage) => {
            let column = active.filter((m) => m.current_stage_key === stage.key)
            return (
              <section key={stage.key} class="board-col" data-drop-zone data-drop-value={stage.key}>
                <h3 class="board-col-head">
                  {stage.name ?? stage.key}
                  <span class="board-col-count">{column.length}</span>
                </h3>
                <ul class="board-cards" data-drop-list>
                  <li class="board-empty">Empty</li>
                  {column.map((member) => (
                    <li
                      key={member.id}
                      class="board-card"
                      data-drag-item={canMove ? true : undefined}
                      data-drag-id={canMove ? member.id : undefined}
                    >
                      <div class="board-card-top">
                        {canPick ? (
                          <input
                            type="checkbox"
                            class="board-card-pick"
                            form="pool-bulk"
                            name="member_id"
                            value={member.id}
                            aria-label={`Select ${member.person?.display_name ?? 'prospect'}`}
                          />
                        ) : null}
                        <a
                          href={`${routes.poolMembersShow.index.href({ memberId: member.id })}${orgQuery}`}
                          class="board-card-name"
                        >
                          {member.person?.display_name ?? member.person_id}
                        </a>
                      </div>
                      {member.person?.primary_email ? (
                        <p class="board-card-meta">{member.person.primary_email}</p>
                      ) : null}
                    </li>
                  ))}
                </ul>
              </section>
            )
          })}
        </div>

        {other.length > 0 ? (
          <>
            <h2 mix={css({ fontSize: '18px', margin: '28px 0 12px' })}>Converted / closed</h2>
            <RowList>
              {other.map((member) => (
                <RowLink
                  key={member.id}
                  href={`${routes.poolMembersShow.index.href({ memberId: member.id })}${orgQuery}`}
                  title={member.person?.display_name ?? member.person_id}
                  meta={`${label(member.status)} · ${label(member.current_stage_key)}`}
                />
              ))}
            </RowList>
          </>
        ) : null}

        <p mix={css({ marginTop: '28px' })}>
          <a href={`${routes.poolsIndex.href()}${orgQuery}`} mix={css({ color: 'var(--bb-accent)' })}>
            ← All pools
          </a>
        </p>
      </Shell>
    )
  }
}

export function PoolMemberShowPage(
  handle: Handle<{
    member: ProjectMember
    transitions: StageTransition[]
    jobs: Job[]
    orgQuery: string
    notice?: string
    error?: string
  }>,
) {
  return () => {
    let { member, transitions, jobs, orgQuery, notice, error } = handle.props
    let stages = member.pipeline?.stages ?? []
    let title = member.person?.display_name ?? 'Pool member'
    let nextStages = stages.map((s) => s.key).filter((key) => key && key !== member.current_stage_key)
    let action = `${routes.poolMembersShow.action.href({ memberId: member.id })}${orgQuery}`

    return (
      <Shell
        title={title}
        eyebrow="Pool member"
        orgQuery={orgQuery}
        backHref={`${routes.poolsShow.index.href({ projectId: member.project_id })}${orgQuery}`}
        backLabel="Pool board"
      >
        <Mute>
          {member.project?.name ?? member.project_id} · {label(member.status)} · stage{' '}
          {label(member.current_stage_key)}
        </Mute>
        {notice ? (
          <p mix={css({ color: 'var(--bb-accent)', fontWeight: 600, marginBottom: '16px' })}>{notice}</p>
        ) : null}
        {error ? (
          <p role="alert" mix={css({ color: 'var(--bb-danger)', marginBottom: '16px' })}>
            {error}
          </p>
        ) : null}

        {member.status === 'active' && signedIn()?.permissions?.includes('project.manage') ? (
          <div class="workflow-grid">
            <form
              method="post"
              action={action}
              mix={css({
                maxWidth: '28rem',
                marginBottom: '28px',
                paddingBottom: '24px',
                borderBottom: '1px solid var(--bb-border)',
              })}
            >
              <h2 mix={css({ fontSize: '16px', margin: '0 0 12px', color: 'var(--bb-accent)' })}>
                Move stage
              </h2>
              <input type="hidden" name="intent" value="transition" />
              <input type="hidden" name="command" value="move" />
              <label
                class="field"
                mix={css({
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '6px',
                  marginBottom: '16px',
                })}
              >
                <span mix={css({ fontSize: '13px', fontWeight: 500, color: 'var(--bb-text-muted)' })}>
                  To stage
                </span>
                <select name="to_stage_key" required>
                  {nextStages.map((key) => {
                    let stage = stages.find((s) => s.key === key)
                    return (
                      <option key={key} value={key}>
                        {stage?.name ?? key}
                      </option>
                    )
                  })}
                </select>
              </label>
              <Field label="Reason (optional)" name="reason" />
              <PrimaryButton type="submit">Move</PrimaryButton>
            </form>

            <form
              method="post"
              action={action}
              mix={css({
                maxWidth: '28rem',
                marginBottom: '28px',
                paddingBottom: '24px',
                borderBottom: '1px solid var(--bb-border)',
              })}
            >
              <h2 mix={css({ fontSize: '16px', margin: '0 0 12px', color: 'var(--bb-accent)' })}>
                Convert to application
              </h2>
              <input type="hidden" name="intent" value="convert" />
              <label
                class="field"
                mix={css({
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '6px',
                  marginBottom: '16px',
                })}
              >
                <span mix={css({ fontSize: '13px', fontWeight: 500, color: 'var(--bb-text-muted)' })}>
                  Job
                </span>
                <select name="job_id">
                  <option value="">Use pool’s linked job</option>
                  {jobs.map((job) => (
                    <option key={job.id} value={job.id}>
                      {job.title}
                    </option>
                  ))}
                </select>
              </label>
              <PrimaryButton type="submit">Convert</PrimaryButton>
            </form>
          </div>
        ) : member.converted_application_id ? (
          <p mix={css({ marginBottom: '24px' })}>
            <a
              href={`${routes.applicationsShow.index.href({ applicationId: member.converted_application_id })}${orgQuery}`}
              mix={css({ color: 'var(--bb-accent)', fontWeight: 600 })}
            >
              Open converted application →
            </a>
          </p>
        ) : null}

        <h2 mix={css({ fontSize: '18px', margin: '8px 0 12px' })}>History</h2>
        {transitions.length === 0 ? (
          <Mute>No transitions recorded.</Mute>
        ) : (
          <ol mix={css({ margin: 0, paddingLeft: '1.2rem', display: 'grid', gap: '8px' })}>
            {transitions.map((t) => (
              <li key={t.id} mix={css({ fontSize: '14px', color: 'var(--bb-text)' })}>
                <strong>{t.command}</strong>
                {t.command === 'move'
                  ? ` ${t.from_stage_key ?? '—'} → ${t.to_stage_key}`
                  : ` (${t.to_stage_key})`}
                {t.reason ? ` — ${t.reason}` : ''}
              </li>
            ))}
          </ol>
        )}

        <p mix={css({ marginTop: '28px', display: 'flex', gap: '16px', flexWrap: 'wrap' })}>
          <a
            href={`${routes.poolsShow.index.href({ projectId: member.project_id })}${orgQuery}`}
            mix={css({ color: 'var(--bb-accent)' })}
          >
            ← Pool board
          </a>
          <a
            href={`${routes.peopleShow.index.href({ personId: member.person_id })}${orgQuery}`}
            mix={css({ color: 'var(--bb-accent)' })}
          >
            Person
          </a>
        </p>
      </Shell>
    )
  }
}
