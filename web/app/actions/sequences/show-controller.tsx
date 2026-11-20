import type { Handle } from 'remix/component'
import { createController } from 'remix/router'

import {
  enrollInSequence,
  enrollPlanned,
  getSequence,
  getSequenceStats,
  listMailboxes,
  listMessageTemplates,
  listPeople,
  listProjects,
  listSavedSearches,
  listSequenceEnrollments,
  planEnrollment,
  previewSequence,
  updateSequenceSteps,
  sessionFromEnv,
  sessionFromRequest,
  type Enrollment,
  type EnrollmentPlan,
  type Mailbox,
  type Person,
  type Project,
  type SavedSearch,
  type Sequence,
  type SequencePreviewStep,
  type SequenceStepStats,
} from '../../data/api.ts'
import { redirectWithNotice, signedIn, takeWorkflowNotice } from '../../data/auth.ts'
import { label, readableMergeFields, statusTone, whenLabel } from '../../data/labels.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { PageSubhead } from '../../ui/page-chrome.tsx'
import { EmptyState, SetupNeeded, Shell } from '../../ui/shell.tsx'
import { DragMove } from '../../ui/public/drag-move.tsx'
import { stepLabel, stepSummary } from './pages.tsx'
import { applyStepIntent, taskKinds, type Step } from './steps.ts'

type Session = NonNullable<ReturnType<typeof sessionFromEnv>>
type Row = Enrollment & { created_at?: string; updated_at?: string }

async function load(session: Session, id: string) {
  const [sequence, enrollments, templates, people, mailboxes, projects, savedSearches, stats] =
    await Promise.all([
      getSequence(session, id),
      listSequenceEnrollments(session, id).catch(() => ({ data: [] as Row[] })),
      listMessageTemplates(session).catch(() => ({ data: [] })),
      listPeople(session, { limit: 200 }).catch(() => ({ data: [] as Person[] })),
      listMailboxes(session).catch(() => ({ data: [] as Mailbox[] })),
      listProjects(session).catch(() => ({ data: [] as Project[] })),
      listSavedSearches(session).catch(() => ({ data: [] as SavedSearch[] })),
      getSequenceStats(session, id).catch(() => null),
    ])
  const names = new Map(
    templates.data.map((row) => [row.key, readableMergeFields(row.name || row.subject || label(row.key))]),
  )
  return {
    sequence,
    enrollments: enrollments.data,
    templates: names,
    people,
    mailboxes: mailboxes.data,
    projects: projects.data,
    savedSearches: savedSearches.data,
    stats: stats?.steps ?? [],
    templateOptions: templates.data.map((row) => ({
      key: row.key,
      name: row.name || row.subject || row.key,
    })),
  }
}

type Sender = { userId: string; email: string }

const addChoices: Array<{ name: string; step: Step }> = [
  { name: 'Email', step: { type: 'email' } },
  { name: 'Wait', step: { type: 'wait', days: 3 } },
  ...taskKinds.map((kind) => ({
    name: kind.name,
    step: { type: 'task', task_type: kind.value, title: kind.title, pause_until_done: true },
  })),
]

/** The inputs for one step, shared by "Add a step" and "Edit". Only the fields its type uses are shown. */
function StepFields(
  handle: Handle<{
    step: Step
    templateOptions: Array<{ key: string; name: string }>
    senders: Sender[]
  }>,
) {
  return () => {
    let { step, templateOptions, senders } = handle.props
    if (step.type === 'wait') {
      return (
        <label class="field">
          <span>Days to wait</span>
          <input name="days" type="number" min="1" max="90" required value={String(step.days ?? 3)} />
        </label>
      )
    }
    if (step.type === 'task') {
      return (
        <>
          <input type="hidden" name="task_type" value={String(step.task_type ?? 'other')} />
          <label class="field">
            <span>What to do</span>
            <input name="title" maxLength={120} required value={String(step.title ?? '')} />
          </label>
          <label class="field">
            <span>Due in days (optional)</span>
            <input
              name="due_in_days"
              type="number"
              min="1"
              max="90"
              value={step.due_in_days ? String(step.due_in_days) : ''}
            />
          </label>
          <label class="check">
            <input type="checkbox" name="pause_until_done" checked={step.pause_until_done !== false} /> Hold
            the sequence until this task is done
          </label>
        </>
      )
    }
    return (
      <>
        <label class="field">
          <span>Email template</span>
          <select name="template_key" required>
            {templateOptions.length === 0 ? <option value="">No templates yet</option> : null}
            {templateOptions.map((option) => (
              <option key={option.key} value={option.key} selected={option.key === step.template_key}>
                {readableMergeFields(option.name)}
              </option>
            ))}
          </select>
        </label>
        <label class="field">
          <span>Send from</span>
          <select name="send_as_user_id">
            <option value="">Whoever enrolls the person</option>
            {senders.map((sender) => (
              <option
                key={sender.userId}
                value={sender.userId}
                selected={sender.userId === step.send_as_user_id}
              >
                {sender.email}
              </option>
            ))}
          </select>
        </label>
      </>
    )
  }
}

function SequenceShowPage(
  handle: Handle<{
    sequence: Sequence
    enrollments: Row[]
    templates: Map<string, string>
    people: { data: Person[] }
    mailboxes: Mailbox[]
    projects: Project[]
    savedSearches: SavedSearch[]
    stats?: SequenceStepStats[]
    templateOptions?: Array<{ key: string; name: string }>
    preview?: SequencePreviewStep[]
    plan?: EnrollmentPlan
    picked?: number
    selection?: string
    mailboxId?: string
    orgQuery: string
    notice?: string
    error?: string
  }>,
) {
  return () => {
    let {
      sequence,
      enrollments,
      templates,
      people,
      mailboxes,
      projects,
      savedSearches,
      stats = [],
      templateOptions = [],
      preview,
      plan,
      picked,
      selection = '',
      mailboxId = '',
      orgQuery,
      notice,
      error,
    } = handle.props
    let planAction = `${routes.sequencesShow.action.href({ sequenceId: sequence.id })}${orgQuery}`
    // "Send from" a teammate: one entry per person who has connected a mailbox of their own.
    let senders: Sender[] = []
    for (const mailbox of mailboxes) {
      if (
        mailbox.user_id &&
        mailbox.status !== 'disconnected' &&
        !senders.some((s) => s.userId === mailbox.user_id)
      ) {
        senders.push({ userId: mailbox.user_id, email: mailbox.email })
      }
    }
    let senderNames = new Map(senders.map((sender) => [sender.userId, sender.email]))
    let steps = sequence.steps ?? []
    let enrolledIds = new Set(
      enrollments.filter((row) => row.status === 'active').map((row) => row.person_id),
    )
    let canEnroll = signedIn()?.permissions?.includes('sequence.enroll') ?? true
    let canEdit = signedIn()?.permissions?.includes('sequence.manage') ?? true
    let counts = enrollments.reduce<Record<string, number>>((out, row) => {
      out[row.status] = (out[row.status] ?? 0) + 1
      return out
    }, {})
    return (
      <Shell
        title={sequence.name}
        eyebrow="Sequence"
        orgQuery={orgQuery}
        backHref={`${routes.sequencesIndex.href()}${orgQuery}`}
        backLabel="Sequences"
      >
        <PageSubhead label="Sequence summary">
          <span class={statusTone(sequence.status)}>{label(sequence.status)}</span>
          <span class="chip">{stepSummary(sequence)}</span>
          {sequence.is_template ? <span class="chip chip-info">Shared template</span> : null}
          {Object.entries(counts).map(([status, count]) => (
            <span key={status} class="chip">
              {count} {label(status).toLowerCase()}
            </span>
          ))}
        </PageSubhead>
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
        <div class="record-workspace">
          <section class="record-section">
            <h2>Steps</h2>
            {steps.length === 0 ? (
              <EmptyState>This sequence has no steps yet. Add the first one below.</EmptyState>
            ) : (
              <div data-drag-root={canEdit ? 'sort' : undefined} data-drop-zone>
                {canEdit ? (
                  <form method="post" action={planAction} data-drag-form hidden>
                    <input type="hidden" name="intent" value="step_move" />
                    <input type="hidden" name="drag_id" />
                    <input type="hidden" name="drag_to" />
                  </form>
                ) : null}
                {canEdit ? <DragMove /> : null}
                <ol class="sequence-steps" data-drop-list>
                  {steps.map((step, index) => {
                    let row = stepLabel(step, templates, senderNames)
                    let stat = stats.find((item) => item.id === step.id)
                    let sent = stat?.messages?.sent ?? 0
                    let stepId = String(step.id ?? '')
                    let draggable = canEdit && Boolean(stepId)
                    return (
                      <li
                        key={stepId || index}
                        class="queue-item sequence-step"
                        data-drag-item={draggable ? true : undefined}
                        data-drag-id={draggable ? stepId : undefined}
                      >
                        {draggable ? (
                          <span class="step-grip" aria-hidden="true" title="Drag to reorder">
                            ⠿
                          </span>
                        ) : null}
                        <div class="body">
                          <span class="title">
                            {index + 1}. {row.title}
                          </span>
                          {row.detail ? <span class="hint">{row.detail}</span> : null}
                          {step.type === 'email' && stat ? (
                            <span class="hint">
                              {sent} sent · {stat.replies} {stat.replies === 1 ? 'reply' : 'replies'}
                            </span>
                          ) : null}
                        </div>
                        {canEdit && stepId ? (
                          <form method="post" action={planAction} class="row-actions">
                            <button
                              class="btn btn-ghost btn-small"
                              type="submit"
                              name="intent"
                              value={`step_up:${stepId}`}
                              disabled={index === 0}
                              aria-label={`Move step ${index + 1} up`}
                            >
                              ↑
                            </button>
                            <button
                              class="btn btn-ghost btn-small"
                              type="submit"
                              name="intent"
                              value={`step_down:${stepId}`}
                              disabled={index === steps.length - 1}
                              aria-label={`Move step ${index + 1} down`}
                            >
                              ↓
                            </button>
                            <button
                              class="btn btn-ghost btn-small"
                              type="submit"
                              name="intent"
                              value={`step_remove:${stepId}`}
                              disabled={steps.length === 1}
                              aria-label={`Remove step ${index + 1}`}
                            >
                              Remove
                            </button>
                          </form>
                        ) : null}
                        {canEdit && stepId ? (
                          <details class="settings-edit">
                            <summary class="btn btn-ghost btn-small" aria-label={`Edit step ${index + 1}`}>
                              Edit
                            </summary>
                            <form method="post" action={planAction} class="form-narrow">
                              <input type="hidden" name="intent" value={`step_update:${stepId}`} />
                              <StepFields step={step} templateOptions={templateOptions} senders={senders} />
                              <button class="btn btn-primary btn-small" type="submit">
                                Save step
                              </button>
                            </form>
                          </details>
                        ) : null}
                      </li>
                    )
                  })}
                </ol>
                {canEdit && steps.length === 1 ? (
                  <p class="sub">
                    A sequence needs at least one step, so this one can't be removed. Add another first.
                  </p>
                ) : null}
              </div>
            )}
            {canEdit ? (
              <div class="step-add" role="group" aria-label="Add a step">
                <h3>Add a step</h3>
                {addChoices.map((choice) => (
                  <details key={choice.name} name="add-step">
                    <summary>{choice.name}</summary>
                    <form method="post" action={planAction} class="form-narrow">
                      <input type="hidden" name="intent" value="step_add" />
                      <input type="hidden" name="step_type" value={String(choice.step.type)} />
                      <StepFields step={choice.step} templateOptions={templateOptions} senders={senders} />
                      <button class="btn btn-primary btn-small" type="submit">
                        Add {choice.name.toLowerCase()}
                      </button>
                    </form>
                  </details>
                ))}
              </div>
            ) : null}
            <details class="workflow-disclosure" open={Boolean(preview)}>
              <summary>Preview for a person</summary>
              <form method="post" action={planAction} class="hub-bar">
                <input type="hidden" name="intent" value="preview" />
                <label class="field">
                  <span>Person</span>
                  <select name="person_id" required>
                    <option value="">Choose a person</option>
                    {people.data.map((person) => (
                      <option key={person.id} value={person.id}>
                        {person.display_name}
                      </option>
                    ))}
                  </select>
                </label>
                <button class="btn btn-ghost btn-small" type="submit">
                  Show messages
                </button>
              </form>
              {preview ? (
                <ol class="stack">
                  {preview.map((step) => (
                    <li key={step.index}>
                      <strong>
                        {step.index + 1}. {label(step.type)}
                      </strong>
                      {step.type === 'email' ? (
                        step.missing_template ? (
                          <p class="mute">Template not found.</p>
                        ) : (
                          <div class="message-preview">
                            <strong>{step.subject}</strong>
                            <pre>{step.body}</pre>
                          </div>
                        )
                      ) : null}
                    </li>
                  ))}
                </ol>
              ) : null}
            </details>
            <p class="sub">
              A reply from the person stops their enrollment.{' '}
              <a href={`${routes.settingsTemplates.index.href()}${orgQuery}`}>Message templates</a>
            </p>
          </section>

          <section class="record-section">
            <h2>
              Enrolled people <span class="tab-count">{enrollments.length}</span>
            </h2>
            {enrollments.length === 0 ? (
              <EmptyState>Nobody is enrolled yet. Enroll someone below.</EmptyState>
            ) : (
              <div class="table-wrap" role="region" aria-label="Enrolled people" tabIndex={0}>
                <table class="table">
                  <thead>
                    <tr>
                      <th>Person</th>
                      <th>Progress</th>
                      <th>Status</th>
                      <th>Mailbox</th>
                      <th>Enrolled</th>
                    </tr>
                  </thead>
                  <tbody>
                    {enrollments.map((row) => {
                      let current = steps[row.step_index]
                      return (
                        <tr key={row.id}>
                          <td>
                            {row.person ? (
                              <a
                                href={`${routes.peopleShow.index.href({ personId: row.person_id })}${orgQuery}`}
                              >
                                {row.person.display_name ?? 'Unnamed person'}
                              </a>
                            ) : (
                              // Erased, merged away, or outside what this member may see: no profile to open.
                              <span class="mute">Removed or restricted person</span>
                            )}
                            {row.person?.primary_email ? (
                              <div class="sub">{row.person.primary_email}</div>
                            ) : null}
                          </td>
                          <td>
                            {row.status === 'active' && current
                              ? `Step ${row.step_index + 1} of ${steps.length}: ${stepLabel(current, templates).title}`
                              : `${Math.min(row.step_index, steps.length)} of ${steps.length} steps done`}
                          </td>
                          <td>
                            <span class={statusTone(row.status)}>{label(row.status)}</span>
                            {row.stop_reason ? <div class="sub">{label(row.stop_reason)}</div> : null}
                          </td>
                          <td>{row.mailbox?.email ?? '—'}</td>
                          <td>{whenLabel(row.created_at) || '—'}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </section>

          {canEnroll && sequence.status === 'active' ? (
            <section class="record-section" aria-label="Enroll a group" id="enroll-review">
              <h2>Enroll a group</h2>
              <p class="sub">
                Pick a pool or a saved search, review who would be enrolled and who would be skipped, then
                confirm.
              </p>
              <form method="post" action={planAction} class="hub-bar">
                <input type="hidden" name="intent" value="plan" />
                <label class="field">
                  <span>Who</span>
                  <select name="selection" required>
                    <option value="">Choose a pool or saved search</option>
                    {projects.map((project) => (
                      <option
                        key={project.id}
                        value={`project:${project.id}`}
                        selected={selection === `project:${project.id}`}
                      >
                        Pool: {project.name}
                      </option>
                    ))}
                    {savedSearches.map((search) => (
                      <option
                        key={search.id}
                        value={`saved_search:${search.id}`}
                        selected={selection === `saved_search:${search.id}`}
                      >
                        Search: {search.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label class="field">
                  <span>Send from</span>
                  <select name="mailbox_id">
                    <option value="">Default mailbox</option>
                    {mailboxes.map((mailbox) => (
                      <option key={mailbox.id} value={mailbox.id} selected={mailboxId === mailbox.id}>
                        {mailbox.email}
                      </option>
                    ))}
                  </select>
                </label>
                <button class="btn btn-ghost btn-small" type="submit">
                  Review who would be enrolled
                </button>
              </form>
              {plan ? (
                <form method="post" action={planAction} class="stack" aria-label="Enrollment review">
                  <input type="hidden" name="intent" value="enroll_planned" />
                  <input type="hidden" name="selection" value={selection} />
                  <input type="hidden" name="mailbox_id" value={mailboxId} />
                  <p>
                    {picked ? `You selected ${picked} ${picked === 1 ? 'person' : 'people'}. ` : ''}
                    <strong>{plan.will_enroll.length}</strong> will be enrolled
                    {plan.skipped.length > 0 ? `, ${plan.skipped.length} skipped` : ''}.
                    {plan.first_send_at && plan.will_enroll.length > 0
                      ? ` First emails go out ${whenLabel(plan.first_send_at)}.`
                      : ''}
                  </p>
                  {plan.will_enroll.length > 0 ? (
                    <ul class="queue">
                      {plan.will_enroll.map((person) => (
                        <li key={person.id} class="queue-item">
                          <label class="check">
                            <input type="checkbox" name="person_ids" value={person.id} checked />{' '}
                            {person.display_name}
                            {person.primary_email ? (
                              <span class="hint"> · {person.primary_email}</span>
                            ) : null}
                          </label>
                        </li>
                      ))}
                    </ul>
                  ) : null}
                  {plan.skipped.length > 0 ? (
                    <details open>
                      <summary>Skipped ({plan.skipped.length})</summary>
                      <ul class="queue">
                        {plan.skipped.map((person) => (
                          <li key={person.id} class="queue-item">
                            <span class="body">
                              <span class="title">{person.display_name}</span>
                              <span class="hint">{label(person.reason)}</span>
                            </span>
                          </li>
                        ))}
                      </ul>
                    </details>
                  ) : null}
                  {plan.will_enroll.length > 0 ? (
                    <button class="btn btn-primary" type="submit">
                      Enroll checked people
                    </button>
                  ) : null}
                </form>
              ) : null}
            </section>
          ) : null}

          {canEnroll && sequence.status === 'active' ? (
            <section class="record-section">
              <h2>Enroll someone</h2>
              <form
                method="post"
                action={`${routes.sequencesShow.action.href({ sequenceId: sequence.id })}${orgQuery}`}
                class="hub-bar"
              >
                <label class="field">
                  <span>Person</span>
                  <select name="person_id" required>
                    <option value="">Choose a person</option>
                    {people.data
                      .filter((person) => !enrolledIds.has(person.id) && !person.do_not_contact)
                      .map((person) => (
                        <option key={person.id} value={person.id}>
                          {/* Two people can share a name; the email tells them apart. */}
                          {person.primary_email
                            ? `${person.display_name} · ${person.primary_email}`
                            : person.display_name}
                        </option>
                      ))}
                  </select>
                </label>
                <label class="field">
                  <span>Send from</span>
                  <select name="mailbox_id">
                    <option value="">Default mailbox</option>
                    {mailboxes.map((mailbox) => (
                      <option key={mailbox.id} value={mailbox.id}>
                        {mailbox.email}
                      </option>
                    ))}
                  </select>
                </label>
                <button class="btn btn-primary btn-small" type="submit">
                  Enroll and send first step
                </button>
              </form>
            </section>
          ) : null}
        </div>
      </Shell>
    )
  }
}

/** Person ids handed over in `?review=`, capped so the URL and the review stay a sane size. */
export function reviewIds(url: URL) {
  return [
    ...new Set(
      (url.searchParams.get('review') ?? '')
        .split(',')
        .map((id) => id.trim())
        .filter((id) => /^[\w-]{1,64}$/.test(id)),
    ),
  ].slice(0, 200)
}

export default createController(routes.sequencesShow, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const data = await load(session, context.params.sequenceId)
        // People picked on the People list or a pool board arrive as ?review=id,id for the same review.
        const picked = reviewIds(context.url)
        let plan: EnrollmentPlan | undefined
        let error: string | undefined
        if (picked.length > 0) {
          try {
            plan = await planEnrollment(session, context.params.sequenceId, { person_ids: picked })
          } catch (failure) {
            error = `Could not review: ${failure instanceof Error ? failure.message : String(failure)}`
          }
        }
        return context.render(
          <SequenceShowPage
            {...data}
            plan={plan}
            picked={picked.length}
            error={error}
            orgQuery={orgQuery(context.url)}
            notice={takeWorkflowNotice()}
          />,
        )
      } catch {
        return new Response('Sequence not found', { status: 404 })
      }
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? '')
      const personId = String(form.get('person_id') ?? '')
      const mailboxId = String(form.get('mailbox_id') ?? '').trim()
      const selection = String(form.get('selection') ?? '')
      const [kind = '', selectionId = ''] = selection.split(':')
      let notice: string | undefined
      let error: string | undefined
      let plan: EnrollmentPlan | undefined
      let preview: SequencePreviewStep[] | undefined
      try {
        if (intent.startsWith('step_')) {
          const sequence = await getSequence(session, context.params.sequenceId)
          const before = sequence.steps ?? []
          const steps = applyStepIntent(before, intent, form)
          // Rails requires at least one step; say so here rather than relay its generic "Validation failed".
          if (steps.length === 0) throw new Error('A sequence needs at least one step.')
          if (steps !== before) await updateSequenceSteps(session, context.params.sequenceId, steps)
          return redirectWithNotice(
            `${routes.sequencesShow.index.href({ sequenceId: context.params.sequenceId })}${orgQuery(context.url)}`,
            steps === before ? 'Nothing changed.' : 'Steps updated.',
          )
        } else if (intent === 'preview') {
          if (!personId) throw new Error('Choose a person to preview.')
          preview = (await previewSequence(session, context.params.sequenceId, personId)).steps
        } else if (intent === 'plan') {
          if (!selectionId) throw new Error('Choose a pool or a saved search.')
          plan = await planEnrollment(session, context.params.sequenceId, {
            ...(kind === 'project' ? { project_id: selectionId } : { saved_search_id: selectionId }),
            ...(mailboxId ? { mailbox_id: mailboxId } : {}),
          })
        } else if (intent === 'enroll_planned') {
          const ids = form.getAll('person_ids').map(String)
          if (ids.length === 0) throw new Error('Check at least one person.')
          const result = await enrollPlanned(session, context.params.sequenceId, {
            person_ids: ids,
            ...(mailboxId ? { mailbox_id: mailboxId } : {}),
          })
          notice = `Enrolled ${result.enrolled}${result.failed ? `, ${result.failed} failed` : ''}${result.skipped ? `, ${result.skipped} skipped` : ''}.`
        } else {
          if (!personId) throw new Error('Choose a person to enroll.')
          await enrollInSequence(session, context.params.sequenceId, {
            person_id: personId,
            ...(mailboxId ? { mailbox_id: mailboxId } : {}),
          })
          notice = 'Enrolled. The first step was sent.'
        }
      } catch (failure) {
        const doing = intent.startsWith('step_') ? 'save the steps' : intent === 'plan' ? 'review' : 'enroll'
        error = `Could not ${doing}: ${failure instanceof Error ? failure.message : String(failure)}`
      }
      const data = await load(session, context.params.sequenceId)
      return context.render(
        <SequenceShowPage
          {...data}
          plan={plan}
          preview={preview}
          selection={selection}
          mailboxId={mailboxId}
          orgQuery={orgQuery(context.url)}
          notice={notice}
          error={error}
        />,
      )
    },
  },
})
