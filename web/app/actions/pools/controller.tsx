import { redirectWithNotice, signedIn, rememberLab } from '../../data/auth.ts'
import { createController } from 'remix/router'

import { createProject, listJobs, sessionFromEnv, sessionFromRequest } from '../../data/api.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { PoolCreatePage } from './pages.tsx'

export default createController(routes.poolsCreate, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const { data: jobs } = await listJobs(session).catch(() => ({
        data: [] as Awaited<ReturnType<typeof listJobs>>['data'],
      }))
      return context.render(
        <PoolCreatePage
          jobs={jobs}
          orgQuery={orgQuery(context.url)}
          initialName={context.url.searchParams.get('name') ?? undefined}
        />,
      )
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const name = String(form.get('name') ?? '').trim()
      const jobId = String(form.get('job_id') ?? '').trim()
      try {
        if (!name) throw new Error('Name is required')
        const project = await createProject(session, { name, ...(jobId ? { job_id: jobId } : {}) })
        const lab = signedIn()?.lab
        if (lab) rememberLab({ ...lab, evidence: { ...lab.evidence, pool: project.id } })
        // Open the new pool: the next thing to do is add prospects to it.
        return redirectWithNotice(
          `${routes.poolsShow.index.href({ projectId: project.id })}${orgQuery(context.url)}`,
          `Opened ${name}. Add prospects below.`,
        )
      } catch (error) {
        const { data: jobs } = await listJobs(session).catch(() => ({
          data: [] as Awaited<ReturnType<typeof listJobs>>['data'],
        }))
        return context.render(
          <PoolCreatePage
            jobs={jobs}
            orgQuery={orgQuery(context.url)}
            notice={`Could not create: ${String(error)}`}
          />,
        )
      }
    },
  },
})
