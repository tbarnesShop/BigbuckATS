import { createController } from 'remix/router'

import {
  createJob,
  getJobFormOptions,
  listQuestionTemplates,
  sessionFromEnv,
  sessionFromRequest,
} from '../../data/api.ts'
import { redirectWithNotice } from '../../data/auth.ts'
import { jobWorkspaceHref } from '../../data/board.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { JobCreatePage } from './pages.tsx'

type Session = NonNullable<ReturnType<typeof sessionFromEnv>>

async function activeTemplates(session: Session) {
  return listQuestionTemplates(session)
    .then((result) =>
      result.data.filter((row) => row.status === 'active').map((row) => ({ id: row.id, name: row.name })),
    )
    .catch(() => [])
}

// Departments, and the members who can manage hiring (they approve the job's offers). Optional: the form
// still works without them.
async function formOptions(session: Session) {
  const options = await getJobFormOptions(session).catch(() => ({ departments: [], members: [] }))
  const managerRoles = new Set(['owner', 'admin', 'hiring_manager', 'hiring-manager'])
  const managers = options.members.filter((member) => managerRoles.has(member.role_key ?? ''))
  return {
    departments: options.departments,
    managers: managers.length ? managers : options.members,
  }
}

export default createController(routes.jobsCreate, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const [templates, options] = await Promise.all([activeTemplates(session), formOptions(session)])
      return context.render(
        <JobCreatePage orgQuery={orgQuery(context.url)} templates={templates} {...options} />,
      )
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const title = String(form.get('title') ?? '').trim()
      const visibility = String(form.get('careers_visibility') ?? 'public')
      const location = String(form.get('location') ?? '').trim()
      const employmentType = String(form.get('employment_type') ?? '')
      const description = String(form.get('description') ?? '').trim()
      const templateId = String(form.get('question_template_id') ?? '')
      const departmentId = String(form.get('department_id') ?? '')
      const hiringManagerId = String(form.get('hiring_manager_user_id') ?? '')
      try {
        if (!title) throw new Error('Title is required')
        if (!['public', 'internal', 'both', 'hidden'].includes(visibility))
          throw new Error('Choose a careers audience')
        const job = await createJob(session, {
          title,
          careers_visibility: visibility as import('../../data/api.ts').CareersVisibility,
          ...(location ? { location } : {}),
          ...(employmentType ? { employment_type: employmentType } : {}),
          ...(description ? { description } : {}),
          ...(templateId ? { question_template_id: templateId } : {}),
          ...(departmentId ? { department_id: departmentId } : {}),
          ...(hiringManagerId ? { hiring_manager_user_id: hiringManagerId } : {}),
        })
        return redirectWithNotice(
          `${jobWorkspaceHref(job.id, orgQuery(context.url), { tab: 'settings' })}#hiring-team`,
          hiringManagerId
            ? `Opened ${title}. Add interviewers to the hiring team next.`
            : `Opened ${title}. Add the hiring team next.`,
        )
      } catch (error) {
        const [templates, options] = await Promise.all([activeTemplates(session), formOptions(session)])
        return context.render(
          <JobCreatePage
            orgQuery={orgQuery(context.url)}
            title={title}
            audience={visibility}
            location={location}
            employmentType={employmentType}
            description={description}
            templates={templates}
            templateId={templateId}
            departmentId={departmentId}
            hiringManagerId={hiringManagerId}
            {...options}
            notice={`Could not create: ${String(error)}`}
          />,
        )
      }
    },
  },
})
