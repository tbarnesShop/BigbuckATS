import { createController } from 'remix/router'

import {
  applyConfigPlan,
  createCompany,
  createConfigPlan,
  createDncCompany,
  createWebhook,
  deleteDncCompany,
  listCompanies,
  listCompliancePolicies,
  listConfigPlans,
  listDncCompanies,
  listEvents,
  listWebhooks,
  sessionFromEnv,
  sessionFromRequest,
} from '../../data/api.ts'
import { orgQuery } from '../../data/session.ts'
import { routes } from '../../routes.ts'
import { SetupNeeded } from '../../ui/shell.tsx'
import { AdminPage } from './pages.tsx'

async function load(session: NonNullable<ReturnType<typeof sessionFromEnv>>) {
  const [companies, events, webhooks, plans, policies, dncCompanies] = await Promise.all([
    listCompanies(session),
    listEvents(session),
    listWebhooks(session),
    listConfigPlans(session),
    listCompliancePolicies(session),
    listDncCompanies(session).catch(() => ({ data: [] })),
  ])
  return {
    companies: companies.data,
    events: events.data,
    webhooks: webhooks.data,
    plans: plans.data,
    policies: policies.data,
    dncCompanies: dncCompanies.data,
  }
}

export default createController(routes.admin, {
  actions: {
    async index(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const data = await load(session)
      return context.render(<AdminPage {...data} orgQuery={orgQuery(context.url)} />)
    },
    async action(context) {
      const session = sessionFromRequest(context.url) ?? sessionFromEnv()
      if (!session) return context.render(<SetupNeeded />)
      const form = await context.request.formData()
      const intent = String(form.get('intent') ?? '')
      try {
        let notice = 'Saved'
        if (intent === 'company') {
          await createCompany(session, {
            name: String(form.get('name') ?? '').trim(),
            domain: String(form.get('domain') ?? '').trim() || undefined,
          })
          notice = 'Company created'
        } else if (intent === 'webhook') {
          await createWebhook(session, {
            key: String(form.get('key') ?? '').trim(),
            url: String(form.get('url') ?? '').trim(),
          })
          notice = 'Webhook created'
        } else if (intent === 'config_plan') {
          const raw = String(form.get('documents') ?? '').trim()
          const documents = JSON.parse(raw) as Array<Record<string, unknown>>
          const plan = await createConfigPlan(session, documents)
          notice = `Plan ${plan.id.slice(0, 8)}… (${plan.status}) with ${Array.isArray(plan.change_set) ? plan.change_set.length : 0} changes`
        } else if (intent === 'config_apply') {
          const planId = String(form.get('plan_id') ?? '').trim()
          const result = await applyConfigPlan(session, planId)
          notice = `Applied plan → ${result.plan.status}`
        } else if (intent === 'dnc_create') {
          const companyId = String(form.get('company_id') ?? '').trim()
          const domain = String(form.get('domain') ?? '').trim()
          const reason = String(form.get('reason') ?? '').trim()
          if (!companyId && !domain) throw new Error('Choose a company or enter a domain.')
          await createDncCompany(session, {
            ...(companyId ? { company_id: companyId } : {}),
            ...(domain ? { domain } : {}),
            ...(reason ? { reason } : {}),
          })
          notice = 'Added to do-not-contact list'
        } else if (intent === 'dnc_delete') {
          await deleteDncCompany(session, String(form.get('id') ?? '').trim())
          notice = 'Removed from do-not-contact list'
        }
        const data = await load(session)
        return context.render(<AdminPage {...data} orgQuery={orgQuery(context.url)} notice={notice} />)
      } catch (error) {
        const data = await load(session)
        return context.render(
          <AdminPage {...data} orgQuery={orgQuery(context.url)} notice={`Error: ${String(error)}`} />,
        )
      }
    },
  },
})
