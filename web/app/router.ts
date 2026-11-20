import { storyFor } from './data/lab/stories.ts'
import { createRouter, type RouterContext } from 'remix/router'
import { asyncContext } from 'remix/middleware/async-context'
import { cop } from 'remix/middleware/cop'
import { render } from 'remix/middleware/render'
import { session } from 'remix/middleware/session'
import { staticFiles } from 'remix/middleware/static'

import applicationsController from './actions/applications/controller.tsx'
import careersApplyController from './actions/careers/controller.tsx'
import careersSettingsController from './actions/careers/settings-controller.tsx'
import controller from './actions/controller.tsx'
import jobsCreateController from './actions/jobs/controller.tsx'
import jobsShowController from './actions/jobs/show-controller.tsx'
import offerController from './actions/offer/controller.tsx'
import tasksController from './actions/tasks/controller.tsx'
import proposalsController from './actions/proposals/controller.tsx'
import rediscoveryController from './actions/rediscovery/controller.tsx'
import unsubscribeController from './actions/unsubscribe/controller.tsx'
import offersShowController from './actions/offers/controller.tsx'
import peopleCreateController from './actions/people/controller.tsx'
import peopleShowController from './actions/people/show-controller.tsx'
import adminController from './actions/admin/controller.tsx'
import companiesShowController from './actions/companies/controller.tsx'
import poolsCreateController from './actions/pools/controller.tsx'
import poolMemberController from './actions/pools/member-controller.tsx'
import poolsShowController from './actions/pools/show-controller.tsx'
import sequencesCreateController from './actions/sequences/controller.tsx'
import sequencesShowController from './actions/sequences/show-controller.tsx'
import referralsController from './actions/referrals/controller.tsx'
import requisitionsController from './actions/requisitions/controller.tsx'
import sessionController from './actions/session/controller.tsx'
import loginController from './actions/session/login-controller.tsx'
import { labController, labExecuteController } from './actions/lab/controller.tsx'
import { agentsController, fieldsController, keysController } from './actions/settings/controllers.tsx'
import {
  applicationFormController,
  calendarController,
  importController,
  mailboxesController,
  mailboxInboxController,
  templatesController,
  webhooksController,
} from './actions/settings/sections-controller.tsx'
import themeController from './actions/theme/controller.tsx'
import { renderAssets } from './assets.ts'
import { signedIn, rememberLab, sessionCookie, sessionStorage } from './data/auth.ts'
import { routes } from './routes.ts'
import jobPostingsController from './actions/jobs/postings-controller.tsx'
import questionTemplatesController from './actions/settings/question-templates.tsx'
import scorecardsController from './actions/settings/scorecards.tsx'
import { internalApplyController } from './actions/careers/internal-controller.tsx'
import { notFound } from './ui/not-found.tsx'

const observeLab: import('remix/router').Middleware = async (context, next) => {
  const current = signedIn()
  const stepId = context.url.searchParams.get('labStep')
  if (!current?.lab?.toolToken || !stepId || context.request.method !== 'GET') return next()
  const { story } = await storyFor()
  const step = story.steps.find((step) => step.id === stepId && step.ui)
  const expected = step?.ui ? new URL(step.ui, context.url) : null
  const response = await next()
  if (
    step &&
    expected?.pathname === context.url.pathname &&
    [...expected.searchParams].every(([key, value]) => context.url.searchParams.get(key) === value) &&
    response.status === 200 &&
    (!step.permission || current.permissions?.includes(step.permission))
  ) {
    rememberLab({ ...current.lab, evidence: { ...current.lab.evidence, [`ui:${stepId}`]: 'observed' } })
  }
  return response
}

const responseSecurity: import('remix/router').Middleware = async (_context, next) => {
  const response = await next()
  // Response.redirect() (and some platform Responses) are immutable; copy headers
  // onto a new Response instead of mutating in place.
  const headers = new Headers(response.headers)
  if (signedIn()) headers.set('Cache-Control', 'no-store')
  headers.set('X-Content-Type-Options', 'nosniff')
  headers.set('Referrer-Policy', 'no-referrer')
  headers.set('Content-Security-Policy', "frame-ancestors 'none'; base-uri 'self'; object-src 'none'")
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  })
}

export const router = createRouter({
  // Unknown paths get the app's own 404 page, not the router's plain-text "Not Found: /path". Old or
  // guessed URLs that have a home are redirected there.
  defaultHandler(context) {
    const path = context.url.pathname.replace(/\/+$/, '')
    const moved: Record<string, string> = {
      '/pipeline': routes.jobsIndex.href(),
      '/openings': routes.requisitions.index.href(),
      '/candidates': routes.peopleIndex.href(),
      '/settings/workspace': routes.settingsIndex.href(),
    }
    if (moved[path])
      return Response.redirect(new URL(`${moved[path]}${context.url.search}`, context.url), 302)
    return notFound(context)
  },
  middleware: [
    staticFiles('./public', { index: false }),
    // Rejects cross-site form posts (CSRF) using Sec-Fetch-Site / Origin; the
    // session cookie is also SameSite=Lax.
    cop(),
    asyncContext(),
    session(sessionCookie, sessionStorage),
    render({ assets: renderAssets }),
    observeLab,
    responseSecurity,
  ],
})

export type AppContext = RouterContext<typeof router>

declare module 'remix' {
  interface RouterTypes {
    context: AppContext
  }
}

router.map(routes, controller)
router.map(routes.peopleCreate, peopleCreateController)
router.map(routes.peopleShow, peopleShowController)
router.map(routes.jobsCreate, jobsCreateController)
router.map(routes.jobsShow, jobsShowController)
router.map(routes.poolsCreate, poolsCreateController)
router.map(routes.poolsShow, poolsShowController)
router.map(routes.poolMembersShow, poolMemberController)
router.map(routes.sequencesCreate, sequencesCreateController)
router.map(routes.sequencesShow, sequencesShowController)
router.map(routes.referrals, referralsController)
router.map(routes.requisitions, requisitionsController)
router.map(routes.admin, adminController)
router.map(routes.companiesShow, companiesShowController)
router.map(routes.settingsTemplates, templatesController)
router.map(routes.settingsForm, applicationFormController)
router.map(routes.settingsMailboxes, mailboxesController)
router.map(routes.settingsMailboxInbox, mailboxInboxController)
router.map(routes.settingsCalendar, calendarController)
router.map(routes.settingsImport, importController)
router.map(routes.settingsWebhooks, webhooksController)
router.map(routes.session, sessionController)
router.map(routes.applicationsShow, applicationsController)
router.map(routes.offersShow, offersShowController)
router.map(routes.careersApply, careersApplyController)
router.map(routes.internalCareersApply, internalApplyController)
router.map(routes.careersSettings, careersSettingsController)
router.map(routes.offer, offerController)
router.map(routes.tasks, tasksController)
router.map(routes.proposals, proposalsController)
router.map(routes.jobRediscovery, rediscoveryController)
router.map(routes.unsubscribe, unsubscribeController)
router.map(routes.theme, themeController)
router.map(routes.settingsAgents, agentsController)
router.map(routes.settingsKeys, keysController)
router.map(routes.settingsFields, fieldsController)

router.map(routes.login, loginController)
router.map(routes.lab, labController)
router.map(routes.labExecute, labExecuteController)

router.map(routes.jobPostings, jobPostingsController)
router.map(routes.questionTemplates, questionTemplatesController)
router.map(routes.settingsScorecards, scorecardsController)
