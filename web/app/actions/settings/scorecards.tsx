import { createController } from 'remix/router'
import type { Handle } from 'remix/component'
import {
  createScorecardRubric,
  listScorecardRubrics,
  sessionFromRequest,
  updateScorecardRubric,
  type ScorecardRubric,
} from '../../data/api.ts'
import { signedIn } from '../../data/auth.ts'
import { routes } from '../../routes.ts'
import { Shell, SetupNeeded } from '../../ui/shell.tsx'

type Attribute = { key: string; label: string; guidance: string; required: boolean }
type Draft = { name: string; guidance: string; attributes: Attribute[] }

const canManage = () => Boolean(signedIn()?.permissions?.includes('settings.manage'))

function slug(text: string) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

function draftOf(rubric?: ScorecardRubric): Draft {
  return {
    name: rubric?.name ?? '',
    guidance: rubric?.guidance ?? '',
    attributes: (rubric?.attributes_spec ?? []).map((row) => ({
      key: row.key,
      label: row.label ?? row.name ?? row.key,
      guidance: row.guidance ?? '',
      required: row.required !== false,
    })),
  }
}

function readDraft(form: FormData): Draft {
  const count = Math.min(30, Math.max(0, Number(form.get('attribute_count')) || 0))
  return {
    name: String(form.get('name') ?? '').trim(),
    guidance: String(form.get('guidance') ?? '').trim(),
    attributes: Array.from({ length: count }, (_, i) => ({
      key: String(form.get(`a_key_${i}`) ?? ''),
      label: String(form.get(`a_label_${i}`) ?? '').trim(),
      guidance: String(form.get(`a_guidance_${i}`) ?? '').trim(),
      required: form.get(`a_required_${i}`) === 'on',
    })),
  }
}

/** Existing attributes keep their key (ratings are stored against it); new ones take one from the label. */
function withKeys(attributes: Attribute[]) {
  const taken = new Set(attributes.map((row) => row.key).filter(Boolean))
  return attributes.map((row) => {
    if (row.key) return row
    const base = slug(row.label) || 'attribute'
    let key = base
    for (let n = 2; taken.has(key); n++) key = `${base}-${n}`
    taken.add(key)
    return { ...row, key }
  })
}

function ScorecardsPage(
  handle: Handle<{
    rubrics: ScorecardRubric[]
    draft?: Draft
    editingId?: string
    notice?: string
    error?: string
  }>,
) {
  return () => {
    const { rubrics, draft, editingId, notice, error } = handle.props
    return (
      <Shell
        title="Scorecards"
        eyebrow="Settings"
        backHref={routes.settingsIndex.href()}
        backLabel="Settings"
      >
        <p class="sub">
          A scorecard is the set of things an interviewer rates. Attach one to an interview in a job’s
          interview plan; interviewers then rate each attribute alongside their overall recommendation.
          Without one, an interview takes an overall recommendation and notes only.
        </p>
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
        <div class="rubric-list">
          {canManage() ? (
            <details
              class="feedback-interview rubric-row rubric-new"
              open={editingId === 'new' || rubrics.length === 0}
            >
              <summary>
                <span class="feedback-title">New scorecard</span>
                <span class="rubric-guidance">Name it and list what interviewers rate.</span>
              </summary>
              <RubricEditor draft={editingId === 'new' ? draft : undefined} />
            </details>
          ) : null}
          {rubrics.map((rubric) => {
            const head = (
              <>
                <span class="feedback-title">{rubric.name}</span>
                {rubric.guidance ? <span class="rubric-guidance">{rubric.guidance}</span> : null}
                {canManage() ? <span class="rubric-edit">Edit</span> : null}
                <span class="chip-row">
                  {(rubric.attributes_spec ?? []).map((row) => (
                    <span key={row.key} class={row.required === false ? 'chip chip-outline' : 'chip'}>
                      {row.label ?? row.name ?? row.key}
                      {row.required === false ? ' · optional' : ''}
                    </span>
                  ))}
                </span>
              </>
            )
            return canManage() ? (
              <details
                key={rubric.id}
                class="feedback-interview rubric-row"
                aria-label={rubric.name}
                open={editingId === rubric.id}
              >
                <summary>{head}</summary>
                <RubricEditor rubric={rubric} draft={editingId === rubric.id ? draft : undefined} />
              </details>
            ) : (
              <div
                key={rubric.id}
                class="feedback-interview feedback-unbooked rubric-row"
                aria-label={rubric.name}
              >
                {head}
              </div>
            )
          })}
        </div>
        {rubrics.length === 0 && !canManage() ? <p class="sub">No scorecards yet.</p> : null}
        {canManage() ? null : <p class="sub">Owners and admins can add or change scorecards.</p>}
      </Shell>
    )
  }
}

function RubricEditor(handle: Handle<{ rubric?: ScorecardRubric; draft?: Draft }>) {
  return () => {
    const rubric = handle.props.rubric
    const row = handle.props.draft ?? draftOf(rubric)
    const attributes = row.attributes.length
      ? row.attributes
      : [{ key: '', label: '', guidance: '', required: true }]
    return (
      <form method="post" action={routes.settingsScorecards.action.href()} autocomplete="off">
        <input type="hidden" name="rubric_id" value={rubric?.id ?? ''} />
        <input type="hidden" name="attribute_count" value={attributes.length} />
        <label class="field">
          <span>Scorecard name</span>
          <input
            name="name"
            defaultValue={row.name}
            required
            maxLength={120}
            placeholder="e.g. Coding interview"
          />
        </label>
        <label class="field">
          <span>Guidance for interviewers</span>
          <input name="guidance" defaultValue={row.guidance} maxLength={500} />
        </label>
        <div class="rubric-attributes">
          {attributes.map((attribute, i) => (
            <div key={`${attribute.key}-${i}`} class="rubric-attribute">
              <input type="hidden" name={`a_key_${i}`} value={attribute.key} />
              <label class="field">
                <span>Attribute</span>
                <input
                  name={`a_label_${i}`}
                  aria-label={`Attribute ${i + 1}`}
                  defaultValue={attribute.label}
                  required
                  maxLength={80}
                  placeholder="e.g. Problem solving"
                />
              </label>
              <label class="field">
                <span>What to look for</span>
                <input
                  name={`a_guidance_${i}`}
                  aria-label={`What to look for in attribute ${i + 1}`}
                  defaultValue={attribute.guidance}
                  maxLength={300}
                />
              </label>
              <span class="check">
                <label>
                  <input type="checkbox" name={`a_required_${i}`} checked={attribute.required} /> Required
                </label>
                {attributes.length > 1 ? (
                  <button
                    class="btn btn-ghost btn-small"
                    name="intent"
                    value={`remove_attribute:${i}`}
                    type="submit"
                    formnovalidate
                    aria-label={`Remove attribute ${i + 1}`}
                  >
                    Remove
                  </button>
                ) : null}
              </span>
            </div>
          ))}
        </div>
        <p class="row-actions">
          <button class="btn btn-ghost" name="intent" value="add_attribute" type="submit" formnovalidate>
            Add attribute
          </button>
          <button class="btn btn-primary" name="intent" value="save" type="submit">
            {rubric ? 'Save scorecard' : 'Create scorecard'}
          </button>
        </p>
        {rubric ? (
          <p class="sub">
            Feedback already submitted keeps its ratings. A removed attribute stays on those scorecards.
          </p>
        ) : null}
      </form>
    )
  }
}

export default createController(routes.settingsScorecards, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      try {
        return context.render(<ScorecardsPage rubrics={(await listScorecardRubrics(session)).data} />)
      } catch {
        return new Response('Scorecards unavailable', { status: 403 })
      }
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      if (!canManage()) return new Response('Settings permission required', { status: 403 })
      const form = await context.request.formData()
      const id = String(form.get('rubric_id') ?? '')
      const intent = String(form.get('intent') ?? 'save')
      const draft = readDraft(form)
      const page = async (props: { notice?: string; error?: string; editing?: boolean }) =>
        context.render(
          <ScorecardsPage
            rubrics={(await listScorecardRubrics(session)).data}
            notice={props.notice}
            error={props.error}
            draft={props.editing ? draft : undefined}
            editingId={props.editing ? id || 'new' : undefined}
          />,
        )
      if (intent === 'add_attribute') {
        draft.attributes.push({ key: '', label: '', guidance: '', required: true })
        return page({ editing: true })
      }
      if (intent.startsWith('remove_attribute:')) {
        draft.attributes.splice(Number(intent.split(':')[1]), 1)
        return page({ editing: true })
      }
      try {
        const attributes = withKeys(draft.attributes.filter((row) => row.label))
        if (!draft.name) throw new Error('Name the scorecard.')
        if (!attributes.length) throw new Error('Add at least one attribute to rate.')
        const body = {
          name: draft.name,
          guidance: draft.guidance,
          attributes_spec: attributes.map((row) => ({
            key: row.key,
            label: row.label,
            ...(row.guidance ? { guidance: row.guidance } : {}),
            required: row.required,
          })),
        }
        if (id) await updateScorecardRubric(session, id, body)
        else await createScorecardRubric(session, { key: slug(draft.name) || 'scorecard', ...body })
        return page({
          notice: id
            ? 'Scorecard saved.'
            : 'Scorecard created. Attach it to an interview in a job’s interview plan.',
        })
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error)
        return page({
          editing: true,
          error: message.includes('has already been taken')
            ? 'A scorecard with that name already exists. Choose another name.'
            : message,
        })
      }
    },
  },
})
