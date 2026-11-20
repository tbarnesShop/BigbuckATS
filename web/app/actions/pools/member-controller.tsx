import { createController } from 'remix/router'

import {
  convertProjectMember,
  createProjectMemberTransition,
  getProjectMember,
  listJobs,
  listProjectMemberTransitions,
  sessionFromEnv,
  sessionFromRequest,
} from '../../data/api.ts'
import { label } from '../../data/labels.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { PoolMemberShowPage } from './pages.tsx'

async function load(session: NonNullable<ReturnType<typeof sessionFromEnv>>, memberId: string) {
  const [member, transitions, jobs] = await Promise.all([
    getProjectMember(session, memberId),
    listProjectMemberTransitions(session, memberId),
    listJobs(session),
  ])
  return { member, transitions: transitions.data, jobs: jobs.data }
}

export default createController(routes.poolMembersShow, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const data = await load(session, context.params.memberId)
        return context.render(<PoolMemberShowPage {...data} orgQuery={orgQuery(context.url)} />)
      } catch {
        return new Response('Pool member not found', { status: 404 })
      }
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? '')
      try {
        let notice = 'Saved'
        if (intent === 'transition') {
          const toStage = String(form.get('to_stage_key') ?? '').trim()
          const reason = String(form.get('reason') ?? '').trim()
          await createProjectMemberTransition(session, context.params.memberId, {
            command: String(form.get('command') ?? 'move'),
            to_stage_key: toStage || undefined,
            reason: reason || undefined,
          })
          notice = `Moved to ${label(toStage)}.`
        } else if (intent === 'convert') {
          const jobId = String(form.get('job_id') ?? '').trim()
          await convertProjectMember(session, context.params.memberId, jobId || undefined)
          notice = 'Converted to an application on the job.'
        }
        const data = await load(session, context.params.memberId)
        return context.render(
          <PoolMemberShowPage {...data} orgQuery={orgQuery(context.url)} notice={notice} />,
        )
      } catch (error) {
        try {
          const data = await load(session, context.params.memberId)
          return context.render(
            <PoolMemberShowPage {...data} orgQuery={orgQuery(context.url)} error={String(error)} />,
          )
        } catch {
          return new Response(String(error), { status: 502 })
        }
      }
    },
  },
})
