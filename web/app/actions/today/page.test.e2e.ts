import * as assert from 'remix/assert'
import { createTestServer } from 'remix/node-fetch-server/test'
import { describe, it } from 'remix/test'
import { router } from '../../router.ts'
import { routes } from '../../routes.ts'
import { loadBigBuckFixture, startMockRailsApi, permissionsForRole } from '../../../test/mock-rails-api.ts'

// Disposable presentation fixture; does not alter queue predicates or live records.
function cappedTodayResponse(userId: string, now = Date.now()) {
  const soon = new Date(now)
  soon.setHours(23, 59, 59, 999)
  const application = (index: number) => ({
    id: `sample-app-${index}`,
    person: { displayName: `Sample person ${index + 1}` },
    job: { id: 'sample-job', title: 'Platform Engineer' },
  })
  const interview = (index: number, ids = [userId]) => ({
    id: `sample-interview-${index}`,
    interviewKey: 'technical_interview',
    startsAt: soon.toISOString(),
    interviewerUserIds: ids,
    application: application(index),
  })
  return {
    Today: {
      data: {
        viewer: { user: { id: userId, name: 'Sample member' } },
        today: {
          reviews: Array.from({ length: 50 }, (_, index) => application(index)),
          feedback: Array.from({ length: 50 }, (_, index) => interview(index)),
          upcoming: Array.from({ length: 20 }, (_, index) =>
            interview(index, index < 10 ? [userId] : ['someone-else']),
          ),
        },
      },
    },
    TodayOffers: {
      data: {
        today: {
          offersPending: Array.from({ length: 20 }, (_, index) => ({
            id: `sample-offer-${index}`,
            application: application(index),
          })),
        },
      },
    },
    TodayJobs: {
      data: {
        today: {
          jobs: Array.from({ length: 20 }, (_, index) => ({
            id: `sample-job-${index}`,
            title: `Sample job ${index + 1}`,
            activeCount: index + 1,
            openings: 1,
          })),
        },
      },
    },
  }
}

const failure = {
  data: null,
  errors: [{ message: 'Sample section unavailable', extensions: { code: 'unavailable' } }],
}

describe('Today scope and section states', () => {
  it('shows an allowed failed section beside successful queues and retries the same filtered view', async (t) => {
    const fixture = loadBigBuckFixture()
    fixture.graphql_responses = { TodayOffers: failure }
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await page.goto(routes.login.index.href())
    await page.getByLabel('Work email').fill(fixture.users.admin.email)
    await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
    await page.waitForURL('**/today')
    await page.goto('/today?kind=reviews&slug=big-buck-fixture')
    await page
      .getByRole('status')
      .getByText(/Some Today sections/)
      .waitFor()
    const offers = page.getByRole('region', { name: 'Offers', exact: true })
    await offers.getByText('This section couldn’t load.').waitFor()
    assert.equal(await offers.getByText('0 shown', { exact: true }).count(), 0)
    assert.equal(await offers.getByText(/No offers/).count(), 0)
    await page
      .getByRole('region', { name: 'Feedback pending' })
      .getByRole('link', { name: 'Write feedback' })
      .first()
      .waitFor()
    await page
      .getByRole('region', { name: 'Pipeline', exact: true })
      .getByText('Platform Engineer', { exact: true })
      .waitFor()
    const retry = offers.getByRole('link', { name: 'Retry Today →' })
    assert.equal(await retry.getAttribute('href'), '/today?slug=big-buck-fixture&kind=reviews')
    delete fixture.graphql_responses.TodayOffers
    await retry.click()
    await offers.getByRole('link', { name: 'View offers →' }).waitFor()
    assert.equal(await page.getByText(/Some Today sections couldn’t load/).count(), 0)
  })

  it('keeps supporting data after a core query failure without showing false empty personal queues', async (t) => {
    const fixture = loadBigBuckFixture()
    fixture.graphql_responses = {
      Today: { data: { today: null }, errors: [{ message: 'Sample partial failure' }] },
    }
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await page.goto(routes.login.index.href())
    await page.getByLabel('Work email').fill(fixture.users.admin.email)
    await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
    await page.waitForURL('**/today')
    for (const name of ['Interviews today', 'Feedback pending', 'Applications']) {
      const region = page.getByRole('region', { name, exact: true })
      await region.getByText('This section couldn’t load.').waitFor()
      assert.equal(await region.getByText(/No more|No scorecards|No applicants|0 shown/).count(), 0)
    }
    await page
      .getByRole('region', { name: 'Offers', exact: true })
      .getByRole('link', { name: 'View offers →' })
      .waitFor()
    await page
      .getByRole('region', { name: 'Pipeline', exact: true })
      .getByText('Platform Engineer', { exact: true })
      .waitFor()
  })

  it('qualifies capped counts, keeps interviews personal and links to the displayed queue', async (t) => {
    const fixture = loadBigBuckFixture()
    fixture.graphql_responses = cappedTodayResponse(fixture.users.admin.id)
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await page.goto(routes.login.index.href())
    await page.getByLabel('Work email').fill(fixture.users.admin.email)
    await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
    await page.waitForURL('**/today')
    const interviews = page.getByRole('region', { name: 'Interviews today', exact: true })
    await interviews.getByText('10 shown', { exact: true }).waitFor()
    assert.equal(await interviews.getByRole('link', { name: 'Open', exact: true }).count(), 10)
    assert.equal(await interviews.getByText('Sample person 11', { exact: true }).count(), 0)
    await page
      .getByRole('region', { name: 'Feedback pending', exact: true })
      .getByText('50 shown', { exact: true })
      .waitFor()
    const apps = page.getByRole('region', { name: 'Applications', exact: true })
    await apps.getByText('50 shown', { exact: true }).waitFor()
    await apps.getByRole('link', { name: 'Review applicants →' }).click()
    assert.equal(await apps.getByRole('link', { name: 'Review', exact: true }).count(), 50)
    assert.match(await page.url(), /kind=reviews/)
    const offers = page.getByRole('region', { name: 'Offers', exact: true })
    await offers.getByText('20 shown', { exact: true }).waitFor()
    assert.equal(
      await offers.getByRole('link', { name: 'View offers →' }).getAttribute('href'),
      '/offers?tab=pending',
    )
    assert.equal(await page.getByRole('region', { name: 'Coming up', exact: true }).count(), 0)
    assert.equal(await page.getByRole('heading', { name: 'Agents', exact: true }).count(), 0)
  })

  it('omits forbidden sections and counts, and respects role capabilities for actions', async (t) => {
    const fixture = loadBigBuckFixture()
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    // Real available role fixtures plus custom capability fixtures: no new production roles.
    for (const [role, permissions] of [
      ['recruiter', permissionsForRole('recruiter')],
      ['hiring_manager', permissionsForRole('hiring_manager')],
      // The seeded interviewer uses the recruiter preset, matching BigBuckDataset.
      ['interviewer_eng', permissionsForRole('recruiter')],
      ['interviewer', ['application.read', 'scorecard.write']],
      ['coordinator', ['application.read', 'job.read', 'interview.schedule']],
      ['no_access', []],
    ] as Array<[string, string[]]>) {
      const user = fixture.users[role] ?? fixture.users.admin
      fixture.graphql_responses = {
        Viewer: {
          data: {
            viewer: {
              organizationId: fixture.organization.id,
              actorType: 'user',
              roleKey: role,
              permissions,
              user: { id: user.id, name: user.name, email: user.email },
              agent: null,
            },
          },
        },
      }
      await page.goto(routes.login.index.href())
      await page.getByLabel('Work email').fill(user.email)
      await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
      await page.waitForURL('**/today')
      const canRead = permissions.includes('application.read')
      assert.equal(
        await page.getByRole('region', { name: 'Offers', exact: true }).count(),
        canRead && permissions.includes('offer.read') ? 1 : 0,
      )
      assert.equal(
        await page.getByRole('region', { name: 'Pipeline', exact: true }).count(),
        canRead && permissions.includes('job.read') ? 1 : 0,
      )
      assert.equal(
        await page.getByRole('link', { name: 'Analytics →', exact: true }).count(),
        canRead && permissions.includes('analytics.read') ? 1 : 0,
      )
      if (canRead) {
        const feedback = page.getByRole('region', { name: 'Feedback pending', exact: true })
        await feedback
          .getByRole('link', {
            name: permissions.includes('scorecard.write') ? 'Write feedback' : 'View interview',
            exact: true,
          })
          .first()
          .waitFor()
      } else {
        assert.equal(await page.getByRole('region', { name: 'Applications', exact: true }).count(), 0)
        await page.getByText('Your role doesn’t include this recruiting overview.').waitFor()
      }
    }
  })
})
