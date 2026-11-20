import { createController } from 'remix/router'

import {
  createReferral,
  listJobs,
  listReferrals,
  sessionFromEnv,
  sessionFromRequest,
} from '../../data/api.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { ReferralsPage } from './pages.tsx'

export default createController(routes.referrals, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const [referrals, jobs] = await Promise.all([listReferrals(session), listJobs(session)])
      return context.render(
        <ReferralsPage
          referrals={referrals.data}
          jobs={jobs.data}
          orgQuery={orgQuery(context.url)}
        />,
      )
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      try {
        const displayName = String(form.get('display_name') ?? '').trim()
        if (!displayName) throw new Error('Name is required')
        await createReferral(session, {
          display_name: displayName,
          email: String(form.get('email') ?? '').trim() || undefined,
          job_id: String(form.get('job_id') ?? '').trim() || undefined,
          note: String(form.get('note') ?? '').trim() || undefined,
        })
        const [referrals, jobs] = await Promise.all([listReferrals(session), listJobs(session)])
        return context.render(
          <ReferralsPage
            referrals={referrals.data}
            jobs={jobs.data}
            orgQuery={orgQuery(context.url)}
            notice={`Referred ${displayName}`}
          />,
        )
      } catch (error) {
        const [referrals, jobs] = await Promise.all([listReferrals(session), listJobs(session)])
        return context.render(
          <ReferralsPage
            referrals={referrals.data}
            jobs={jobs.data}
            orgQuery={orgQuery(context.url)}
            notice={`Could not create: ${String(error)}`}
          />,
        )
      }
    },
  },
})
