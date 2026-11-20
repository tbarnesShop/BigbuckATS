import { createController } from 'remix/router'
import {
  getJob,
  listJobPostings,
  listQuestionTemplates,
  saveJobPosting,
  sessionFromRequest,
  type CareersVisibility,
} from '../../data/api.ts'
import { signedIn } from '../../data/auth.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { addQuestion, readQuestions } from './question-editor.tsx'
import { JobPostingsPage, type PostingDraft } from './postings-page.tsx'

async function load(jobId: string) {
  const session = sessionFromRequest()!
  const [job, postings, templates] = await Promise.all([
    getJob(session, jobId),
    listJobPostings(session, jobId),
    listQuestionTemplates(session),
  ])
  return {
    job,
    postings: postings.data,
    baseline: postings.application_form,
    templates: templates.data,
    slug: signedIn()?.organizationSlug,
    canManage: signedIn()?.permissions?.includes('job.manage') ?? false,
  }
}
export default createController(routes.jobPostings, {
  actions: {
    async index(context) {
      if (!sessionFromRequest()) return context.render(<SetupNeeded />)
      try {
        return context.render(<JobPostingsPage {...await load(context.params.jobId)} />)
      } catch {
        return new Response('Postings unavailable', { status: 403 })
      }
    },
    async action(context) {
      const session = sessionFromRequest()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const id = String(form.get('posting_id') ?? '')
      const intent = String(form.get('intent') ?? 'save')
      const draft: PostingDraft = {
        title: String(form.get('title') ?? '').trim(),
        audience: String(form.get('audience')) as CareersVisibility,
        status: String(form.get('status')),
        templateChoice: String(form.get('template_choice') ?? ''),
        questions: readQuestions(form),
        description: String(form.get('description') ?? '').trim(),
        location: String(form.get('location') ?? '').trim(),
        employment_type: String(form.get('employment_type') ?? ''),
      }
      try {
        const loaded = await load(context.params.jobId)
        if (!loaded.canManage) return new Response('Job management permission required', { status: 403 })
        if (id && !loaded.postings.some((p) => p.id === id))
          return new Response('Posting not found', { status: 404 })
        if (intent === 'add_question') draft.questions = addQuestion(draft.questions)
        else if (intent.startsWith('remove_question:'))
          draft.questions.splice(Number(intent.split(':')[1]), 1)
        else {
          await saveJobPosting(session, context.params.jobId, id || null, {
            title: draft.title,
            audience: draft.audience,
            status: draft.status,
            questions: draft.questions,
            description: draft.description,
            location: draft.location,
            employment_type: draft.employment_type || null,
            ...(id ? { expected_version: Number(form.get('expected_version')) } : {}),
            ...(draft.templateChoice !== 'keep'
              ? { question_template_id: draft.templateChoice || null }
              : {}),
          })
          return context.render(
            <JobPostingsPage {...await load(context.params.jobId)} notice="Posting saved." />,
          )
        }
        return context.render(<JobPostingsPage {...loaded} draft={draft} editingId={id || 'new'} />)
      } catch (error) {
        return context.render(
          <JobPostingsPage
            {...await load(context.params.jobId)}
            draft={draft}
            editingId={id || 'new'}
            error={String(error)}
          />,
        )
      }
    },
  },
})
