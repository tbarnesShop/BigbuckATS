import { createController } from 'remix/router'

import {
  createRequisition,
  listRequisitions,
  openRequisition,
  sessionFromEnv,
  sessionFromRequest,
} from '../../data/api.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { RequisitionsPage } from './pages.tsx'

export default createController(routes.requisitions, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const { data } = await listRequisitions(session)
      return context.render(
        <RequisitionsPage requisitions={data} orgQuery={orgQuery(context.url)} />,
      )
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? 'create')
      try {
        if (intent === 'open') {
          await openRequisition(session, String(form.get('requisition_id')))
          const { data } = await listRequisitions(session)
          return context.render(
            <RequisitionsPage
              requisitions={data}
              orgQuery={orgQuery(context.url)}
              notice="Requisition opened"
            />,
          )
        }
        const code = String(form.get('code') ?? '').trim()
        const title = String(form.get('title') ?? '').trim()
        const headcount = Number(form.get('headcount') ?? 1)
        if (!code || !title) throw new Error('Code and title are required')
        await createRequisition(session, { code, title, headcount: headcount || 1 })
        const { data } = await listRequisitions(session)
        return context.render(
          <RequisitionsPage
            requisitions={data}
            orgQuery={orgQuery(context.url)}
            notice={`Created ${code}`}
          />,
        )
      } catch (error) {
        const { data } = await listRequisitions(session)
        return context.render(
          <RequisitionsPage
            requisitions={data}
            orgQuery={orgQuery(context.url)}
            notice={`Could not save: ${String(error)}`}
          />,
        )
      }
    },
  },
})
