import { createController } from 'remix/router'
import type { Handle } from 'remix/component'
import {
  listQuestionTemplates,
  saveQuestionTemplate,
  sessionFromRequest,
  type QuestionTemplate,
  type PostingQuestion,
} from '../../data/api.ts'
import { signedIn } from '../../data/auth.ts'
import { routes } from '../../routes.ts'
import { Shell, SetupNeeded } from '../../ui/shell.tsx'
import { QuestionEditor, addQuestion, readQuestions } from '../jobs/question-editor.tsx'
import { label } from '../../data/labels.ts'

type Draft = { name: string; status: string; questions: PostingQuestion[] }
function TemplatePage(
  handle: Handle<{
    templates: QuestionTemplate[]
    draft?: Draft
    editingId?: string
    notice?: string
    error?: string
  }>,
) {
  return () => (
    <Shell
      title="Application question templates"
      eyebrow="Settings"
      backHref={routes.settingsIndex.href()}
      backLabel="Settings"
    >
      <p class="sub">
        Reusable questions owned by their creator. Owners and settings administrators can edit them;
        recruiters can reuse them. Organization compliance questions are always included separately.
      </p>
      {handle.props.notice ? (
        <p class="notice" role="status">
          {handle.props.notice}
        </p>
      ) : null}
      {handle.props.error ? (
        <p class="notice-bad" role="alert">
          {handle.props.error}
        </p>
      ) : null}
      {handle.props.templates.map((t) => (
        <section class="section-card" key={t.id}>
          <h2>{t.name}</h2>
          <p>
            {t.owner_name} · {label(t.status)} · version {t.version}
          </p>
          {t.can_edit ? (
            <details class="workflow-disclosure" open={handle.props.editingId === t.id}>
              <summary>Edit template</summary>
              <TemplateEditor
                template={t}
                draft={handle.props.editingId === t.id ? handle.props.draft : undefined}
              />
            </details>
          ) : (
            <ol>
              {t.questions.map((q) => (
                <li key={q.key}>{q.label}</li>
              ))}
            </ol>
          )}
        </section>
      ))}
      {signedIn()?.permissions?.includes('job.manage') ? (
        <details
          class="workflow-disclosure"
          open={handle.props.editingId === 'new' || handle.props.templates.length === 0}
        >
          <summary>New template</summary>
          <TemplateEditor draft={handle.props.editingId === 'new' ? handle.props.draft : undefined} />
        </details>
      ) : null}
    </Shell>
  )
}
function TemplateEditor(handle: Handle<{ template?: QuestionTemplate; draft?: Draft }>) {
  return () => {
    const t = handle.props.template
    const row = handle.props.draft ?? {
      name: t?.name ?? '',
      status: t?.status ?? 'active',
      questions: t?.questions ?? [],
    }
    return (
      <form method="post" action={routes.questionTemplates.action.href()}>
        <input type="hidden" name="template_id" value={t?.id ?? ''} />
        <input type="hidden" name="expected_version" value={t?.version ?? ''} />
        <label class="field">
          <span>Template name</span>
          <input name="name" defaultValue={row.name} required />
        </label>
        <label class="field">
          <span>Template status</span>
          <select name="status" aria-label="Template status">
            <option value="active" selected={row.status === 'active'}>
              Active
            </option>
            <option value="archived" selected={row.status === 'archived'}>
              Archived
            </option>
          </select>
        </label>
        <QuestionEditor questions={row.questions} />
        <p>
          <button class="btn btn-primary" name="intent" value="save" type="submit">
            Save template
          </button>
        </p>
      </form>
    )
  }
}
export default createController(routes.questionTemplates, {
  actions: {
    async index(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      try {
        return context.render(<TemplatePage templates={(await listQuestionTemplates(session)).data} />)
      } catch {
        return new Response('Templates unavailable', { status: 403 })
      }
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const id = String(form.get('template_id') ?? '')
      const intent = String(form.get('intent') ?? 'save')
      const draft: Draft = {
        name: String(form.get('name') ?? '').trim(),
        status: String(form.get('status')),
        questions: readQuestions(form),
      }
      try {
        if (!signedIn()?.permissions?.includes('job.manage'))
          return new Response('Job management permission required', { status: 403 })
        const templates = (await listQuestionTemplates(session)).data
        if (id && !templates.some((t) => t.id === id && t.can_edit))
          return new Response('Template ownership required', { status: 403 })
        if (intent === 'add_question') draft.questions = addQuestion(draft.questions)
        else if (intent.startsWith('remove_question:'))
          draft.questions.splice(Number(intent.split(':')[1]), 1)
        else {
          await saveQuestionTemplate(session, id || null, {
            ...draft,
            questions: draft.questions,
            ...(id ? { expected_version: Number(form.get('expected_version')) } : {}),
          })
          return context.render(
            <TemplatePage
              templates={(await listQuestionTemplates(session)).data}
              notice="Template saved. Existing postings keep their saved questions."
            />,
          )
        }
        return context.render(
          <TemplatePage
            templates={(await listQuestionTemplates(session)).data}
            draft={draft}
            editingId={id || 'new'}
          />,
        )
      } catch (error) {
        return context.render(
          <TemplatePage
            templates={(await listQuestionTemplates(session)).data}
            draft={draft}
            editingId={id || 'new'}
            error={String(error)}
          />,
        )
      }
    },
  },
})
