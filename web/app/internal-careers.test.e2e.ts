import * as assert from 'remix/assert'
import { createTestServer } from 'remix/node-fetch-server/test'
import { describe, it } from 'remix/test'
import { router } from './router.ts'
import { routes } from './routes.ts'
import { startMockRailsApi } from '../test/mock-rails-api.ts'

describe('internal careers', () => {
  it('requires sign-in and connects job publication to employee applications', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await page.goto(routes.internalCareers.href())
    await page.waitForURL((url) => url.pathname === routes.login.index.href())
    await page.getByLabel('Work email').fill(api.fixture.users.admin.email)
    await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
    await page.waitForURL((url) => url.pathname === routes.today.href())
    const job = api.fixture.jobs.find((job) => job.title === 'Platform Engineer')!
    await page.goto(routes.jobsShow.index.href({ jobId: job.id }) + '?tab=settings')
    await page.getByLabel('Audience', { exact: true }).selectOption('internal')
    await page.getByLabel('Publication', { exact: true }).selectOption('true')
    await page.getByRole('button', { name: 'Save careers settings' }).click()
    await page.getByText('Careers settings saved.').waitFor()
    await page.goto(routes.careersIndex.href() + '?slug=' + api.fixture.organization.slug)
    assert.equal(await page.getByRole('link', { name: /Platform Engineer/ }).count(), 0)
    await page.getByRole('link', { name: 'Employee? See internal roles', exact: true }).click()
    await page.getByRole('heading', { name: 'Internal opportunities' }).waitFor()
    assert.equal(await page.locator('script[type="application/ld+json"]').count(), 0)
    await page
      .getByRole('link', { name: /Platform Engineer/ })
      .first()
      .click()
    await page
      .getByText(`Applying as ${api.fixture.users.admin.name} (${api.fixture.users.admin.email}).`)
      .waitFor()
    assert.equal(await page.getByLabel('Email', { exact: true }).count(), 0)
    await page.getByRole('button', { name: 'Submit application' }).click()
    await page.getByText('Application submitted. A recruiter will follow up.').waitFor()
    await page.getByRole('link', { name: '← All openings' }).click()
    await page.getByRole('heading', { name: 'Internal opportunities' }).waitFor()
    await page.goto(routes.jobsShow.index.href({ jobId: job.id }) + '?tab=settings')
    await page.getByLabel('Publication', { exact: true }).selectOption('false')
    await page.getByRole('button', { name: 'Save careers settings' }).click()
    await page.getByText('Careers settings saved.').waitFor()
    await page.goto(routes.internalCareers.href())
    assert.equal(await page.getByRole('link', { name: /Platform Engineer/ }).count(), 0)
    await page.setViewportSize({ width: 390, height: 844 })
    await page.getByRole('heading', { name: 'Internal opportunities' }).waitFor()
  })
})
