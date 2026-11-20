import { createController } from 'remix/router'

import { getCompany, listAffiliations, sessionFromEnv, sessionFromRequest } from '../../data/api.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { CompanyShowPage } from './pages.tsx'

export default createController(routes.companiesShow, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      try {
        const [company, affiliations] = await Promise.all([
          getCompany(session, context.params.companyId),
          listAffiliations(session, undefined, context.params.companyId).catch(() => ({ data: [] })),
        ])
        return context.render(
          <CompanyShowPage company={company} affiliations={affiliations.data} orgQuery={orgQuery(context.url)} />,
        )
      } catch {
        return new Response('Company not found', { status: 404 })
      }
    },
    async action() {
      return new Response('Companies are read here.', { status: 405 })
    },
  },
})
