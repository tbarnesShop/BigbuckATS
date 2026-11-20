import * as assert from 'remix/assert'
import { createTestServer } from 'remix/node-fetch-server/test'
import { describe, it } from 'remix/test'
import { router } from './router.ts'
import { routes } from './routes.ts'
import { loadBigBuckFixture, startMockRailsApi } from '../test/mock-rails-api.ts'

describe('posting application questions', () => {
  it('creates a reusable template and separate external/internal forms, then reviews responses', async (t) => {
    const fixture = loadBigBuckFixture()
    fixture.reject_next_application = true
    fixture.application_form = {
      required_fields: ['display_name', 'email'],
      standard_fields: ['display_name', 'email'],
      screening_questions: [
        {
          id: 'compliance',
          key: 'compliance',
          label: 'Organization compliance',
          field_type: 'boolean',
          required: true,
          options: [],
        },
      ],
    }
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await page.goto(routes.login.index.href())
    await page.getByLabel('Work email').fill(api.fixture.users.admin.email)
    await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
    await page.waitForURL((url) => url.pathname === routes.today.href())
    await page.goto(routes.questionTemplates.index.href())
    const newTemplate = page
      .locator('form')
      .filter({ has: page.getByRole('button', { name: 'Save template' }) })
      .last()
    await newTemplate.getByLabel('Template name', { exact: true }).fill('Engineering questions')
    await newTemplate.getByRole('button', { name: 'Add question', exact: true }).click()
    await newTemplate.getByLabel('Question 1 wording').fill('Your skills')
    await newTemplate.getByLabel('Question 1 type').selectOption('multi_select')
    await newTemplate.getByLabel('Required answer').check()
    await newTemplate
      .getByLabel('Question 1 choices (one per line, for select types)')
      .fill('Ruby\nTypeScript')
    await newTemplate.getByRole('button', { name: 'Save template' }).click()
    await page.getByText('Template saved. Existing postings keep their saved questions.').waitFor()
    const job = api.fixture.jobs.find((j) => j.title === 'Platform Engineer')!
    await page.goto(routes.jobPostings.index.href({ jobId: job.id }))
    await page.getByRole('heading', { name: 'Organization questions — always included first' }).waitFor()
    const newPosting = page
      .locator('form')
      .filter({ has: page.getByRole('button', { name: 'Create posting', exact: true }) })
    await newPosting.getByLabel('Posting title').fill('External platform engineer')
    await newPosting.getByLabel('Posting audience').selectOption('public')
    await newPosting.getByLabel('Posting status').selectOption('published')
    await newPosting.getByLabel('Question template').selectOption('template-1')
    await newPosting.getByRole('button', { name: 'Add question', exact: true }).click()
    await newPosting.getByLabel('Question 1 wording').fill('Why this role?')
    await newPosting.getByLabel('Question 1 type').selectOption('long_text')
    await newPosting.getByLabel('Required answer').check()
    await newPosting.getByRole('button', { name: 'Create posting', exact: true }).click()
    await page.getByText('Posting saved.', { exact: true }).waitFor()
    await page.getByText('New posting', { exact: true }).click()
    await newPosting.getByLabel('Posting title').fill('Internal platform opportunity')
    await newPosting.getByLabel('Posting audience').selectOption('internal')
    await newPosting.getByLabel('Posting status').selectOption('published')
    await newPosting.getByRole('button', { name: 'Add question', exact: true }).click()
    await newPosting.getByLabel('Question 1 wording').fill('Why move teams?')
    await newPosting.getByLabel('Required answer').check()
    await newPosting.getByRole('button', { name: 'Create posting', exact: true }).click()
    await page.getByText('Posting saved.', { exact: true }).waitFor()
    await page.getByRole('link', { name: 'Open external application' }).click()
    await page.getByRole('heading', { name: 'External platform engineer' }).waitFor()
    assert.equal(await page.getByLabel('Why move teams?').count(), 0)
    const questionOrder = await page.locator('form label').allTextContents()
    assert.ok(
      questionOrder.findIndex((s) => s.includes('Organization compliance')) <
        questionOrder.findIndex((s) => s.includes('Your skills')),
    )
    assert.equal(await page.getByLabel('Your skills').getAttribute('multiple'), '')
    await page.getByLabel('Full name').fill('Test Applicant')
    await page.getByLabel('Email', { exact: true }).fill('test@example.test')
    await page.getByLabel('Organization compliance').selectOption('false')
    await page.getByLabel('Your skills').selectOption(['Ruby', 'TypeScript'])
    await page.getByLabel('Why this role?').fill('Building reliable platforms')
    await page.getByRole('button', { name: 'Submit application' }).click()
    await page.getByRole('alert').waitFor()
    assert.equal(await page.getByLabel('Full name').inputValue(), 'Test Applicant')
    assert.equal(await page.getByLabel('Organization compliance').inputValue(), 'false')
    assert.equal(await page.getByLabel('Why this role?').inputValue(), 'Building reliable platforms')
    assert.deepEqual(
      await page
        .getByLabel('Your skills')
        .evaluate((select) => Array.from((select as HTMLSelectElement).selectedOptions).map((o) => o.value)),
      ['Ruby', 'TypeScript'],
    )
    await page.getByRole('button', { name: 'Submit application' }).click()
    await page.getByText('Application submitted. A recruiter will follow up.').waitFor()
    await page.goto(routes.applicationsShow.index.href({ applicationId: 'app-posting' }))
    await page.getByText('Application responses', { exact: true }).click()
    await page.getByText('Ruby, TypeScript', { exact: true }).waitFor()
    await page.getByText('Building reliable platforms', { exact: true }).waitFor()
    await page.goto(routes.internalCareers.href())
    assert.equal(await page.getByRole('link', { name: /External platform engineer/ }).count(), 0)
    await page
      .getByRole('link', { name: /Internal platform opportunity/ })
      .first()
      .click()
    await page.getByLabel('Why move teams?').waitFor()
    assert.equal(await page.getByLabel('Your skills').count(), 0)
    await page.getByLabel('Organization compliance').selectOption('true')
    await page.getByLabel('Why move teams?').fill('Growing into a new domain')
    await page.getByRole('button', { name: 'Submit application' }).click()
    await page.getByText('Application submitted. A recruiter will follow up.').waitFor()
    await page.setViewportSize({ width: 390, height: 844 })
    await page.getByRole('link', { name: '← All openings' }).click()
    await page.getByRole('heading', { name: 'Internal opportunities' }).waitFor()
  })
})
