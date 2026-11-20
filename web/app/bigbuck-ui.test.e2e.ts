import * as assert from 'remix/assert'
import { createTestServer } from 'remix/node-fetch-server/test'
import { describe, it } from 'remix/test'

import { router } from './router.ts'
import { routes } from './routes.ts'
import { loadBigBuckFixture, startMockRailsApi } from '../test/mock-rails-api.ts'

async function signInAs(
  page: {
    setDefaultTimeout(timeout: number): void
    goto(url: string): Promise<unknown>
    getByLabel(label: string): { fill(v: string): Promise<void> }
    getByRole(role: 'button', opts: { name: string }): { click(): Promise<void> }
    waitForURL(url: (url: URL) => boolean): Promise<void>
  },
  email: string,
) {
  page.setDefaultTimeout(15_000)
  await page.goto(routes.login.index.href())
  await page.getByLabel('Work email').fill(email)
  await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
  await page.waitForURL((url) => url.pathname === routes.today.href())
}

describe('Big Buck UI roles', () => {
  it('mobile navigation contains focus, closes with Escape, and survives desktop resize', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await page.setViewportSize({ width: 390, height: 844 })
    await signInAs(page, api.fixture.users.admin.email)
    await page.locator('.nav-drawer[data-enhanced]').waitFor({ state: 'attached' })
    const menu = page.getByRole('button', { name: 'Menu', exact: true })
    await menu.click()
    const dialog = page.getByRole('dialog', { name: 'Menu', exact: true })
    await dialog.waitFor()
    await page.waitForFunction(() => document.activeElement?.textContent === 'Close')
    await page.keyboard.press('Shift+Tab')
    assert.equal(await page.evaluate(() => document.activeElement?.textContent), 'Sign out')
    await page.keyboard.press('Tab')
    assert.equal(await page.evaluate(() => document.activeElement?.textContent), 'Close')
    await page.keyboard.press('Escape')
    await dialog.waitFor({ state: 'hidden' })
    assert.equal(await page.evaluate(() => document.activeElement?.textContent?.trim()), 'Menu')
    await menu.click()
    await dialog.waitFor()
    await page.setViewportSize({ width: 1280, height: 900 })
    await page.waitForFunction(() => !document.querySelector('dialog:modal'))
    const primary = page.getByRole('navigation', { name: 'Primary', exact: true })
    assert.equal(
      await primary.getByRole('link', { name: 'Today', exact: true }).getAttribute('aria-current'),
      'page',
    )
    await page.setViewportSize({ width: 320, height: 800 })
    await menu.click()
    await dialog.getByRole('button', { name: 'Close', exact: true }).click()
    assert.equal(await page.evaluate(() => document.activeElement?.textContent?.trim()), 'Menu')
  })

  it('search and Create dismiss without losing typed search or changing link permissions', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await signInAs(page, api.fixture.users.recruiter.email)
    await page.locator('.command-bar[data-enhanced]').waitFor({ state: 'attached' })
    const search = page.getByRole('searchbox', { name: 'Search or jump' })
    await search.fill('jobs')
    const suggestions = page.getByRole('list', { name: 'Suggested destinations' })
    await suggestions.waitFor()
    await search.press('ArrowDown')
    assert.equal(await page.evaluate(() => document.activeElement?.tagName), 'A')
    await page.keyboard.press('Escape')
    await suggestions.waitFor({ state: 'hidden' })
    assert.equal(await search.inputValue(), 'jobs')
    assert.equal(await page.evaluate(() => document.activeElement?.id), 'command-q')
    await search.press('Control+k')
    await suggestions.waitFor()
    await page.getByRole('button', { name: '+ Create', exact: true }).click()
    await suggestions.waitFor({ state: 'hidden' })
    const create = page.getByRole('navigation', { name: 'Create', exact: true })
    await create.waitFor()
    assert.equal(await create.getByRole('link', { name: /New job/ }).count(), 1)
    assert.equal(await create.getByRole('link', { name: /New talent pool/ }).count(), 1)
    await page.getByRole('button', { name: '+ Create', exact: true }).press('Escape')
    await create.waitFor({ state: 'hidden' })
    await page.getByRole('button', { name: '+ Create', exact: true }).click()
    await create.waitFor()
    await page.getByRole('heading', { name: 'Today', exact: true }).click()
    await create.waitFor({ state: 'hidden' })
    await search.fill('People')
    await page.getByRole('button', { name: 'Search', exact: true }).click()
    await page.waitForURL((url) => url.pathname === '/search' && url.searchParams.get('q') === 'People')
    await signInAs(page, api.fixture.users.hiring_manager.email)
    assert.equal(await page.getByRole('button', { name: '+ Create', exact: true }).count(), 0)
    await page.getByRole('searchbox', { name: 'Search or jump' }).fill('New talent pool')
    await page.getByText('No commands match. Search still runs when you submit.').waitFor()
  })

  it('mobile navigation remains usable without JavaScript and keeps role filtering', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, api.fixture.users.hiring_manager.email)
    const context = await page
      .context()
      .browser()!
      .newContext({
        javaScriptEnabled: false,
        storageState: await page.context().storageState(),
        viewport: { width: 320, height: 800 },
      })
    t.after(() => context.close())
    const fallback = await context.newPage()
    fallback.setDefaultTimeout(15_000)
    await fallback.goto(page.url())
    const menu = fallback.getByRole('button', { name: 'Menu', exact: true })
    await menu.click()
    const navigation = fallback.getByRole('dialog', { name: 'Menu', exact: true })
    await navigation.waitFor()
    assert.equal(await navigation.getByRole('link', { name: 'Jobs', exact: true }).isVisible(), true)
    assert.equal(await fallback.getByRole('button', { name: '+ Create', exact: true }).count(), 0)
    await menu.click()
    await navigation.waitFor({ state: 'hidden' })
  })

  it('the working frame reflows at narrow widths and with doubled text', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, api.fixture.users.admin.email)
    for (const width of [1440, 1280, 1101, 1100, 981, 980, 769, 768, 390, 320]) {
      await page.setViewportSize({ width, height: 900 })
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true)
      const title = await page.getByRole('heading', { name: 'Today', exact: true }).boundingBox()
      assert.equal(!!title && title.width > 50, true)
    }
    await page.setViewportSize({ width: 1280, height: 900 })
    // Increase computed text roles independently of viewport size; layout must expand with content.
    await page.evaluate(() => {
      const elements = Array.from(document.querySelectorAll<HTMLElement>('body, body *'))
      const sizes = elements.map((element) => getComputedStyle(element).fontSize)
      elements.forEach((element, index) => {
        element.style.fontSize = `${parseFloat(sizes[index]) * 2}px`
      })
    })
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true)
    await page.setViewportSize({ width: 320, height: 800 })
    const reflow = await page.evaluate(() => ({
      width: innerWidth,
      page: document.documentElement.scrollWidth,
      overflowing: Array.from(document.querySelectorAll<HTMLElement>('body *'))
        .filter((node) => {
          const box = node.getBoundingClientRect()
          return box.width > 0 && box.right > innerWidth
        })
        .map((node) => ({
          tag: node.tagName,
          class: node.className,
          width: node.getBoundingClientRect().width,
          right: node.getBoundingClientRect().right,
        })),
    }))
    assert.equal(reflow.page <= reflow.width, true, JSON.stringify(reflow))
    await page.getByRole('button', { name: 'Menu', exact: true }).click()
    const dialog = page.getByRole('dialog', { name: 'Menu', exact: true })
    await dialog.waitFor()
    await dialog.getByRole('button', { name: 'Close', exact: true }).click()
  })

  it('admin sees all candidates including restricted names', async (t) => {
    const fixture = loadBigBuckFixture()
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl

    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.admin.email)
    await page.goto(routes.peopleIndex.href())

    await page.getByRole('heading', { name: 'People' }).waitFor()
    await page.getByText(`${fixture.expectations.admin_count} people shown`).waitFor()
    await page.getByText('Diego Santos').waitFor()
    await page.getByText('Uma Sharma').waitFor()
    await page.getByText('Ava Chen').waitFor()
    await page
      .getByText(/restricted/, { exact: false })
      .first()
      .waitFor()
    await page.getByText('includes restricted').waitFor()

    const brand = page.getByRole('link', { name: 'BigBuck', exact: true }).first()
    assert.equal(await brand.isVisible(), true)
    assert.equal((await brand.getAttribute('href'))?.includes('org='), false)
  })

  it('recruiter does not see restricted candidates in the list', async (t) => {
    const fixture = loadBigBuckFixture()
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl

    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.recruiter.email)
    await page.goto(routes.peopleIndex.href())

    await page.getByText(`${fixture.expectations.recruiter_count} people shown`).waitFor()
    await page.getByText('Ava Chen').waitFor()
    assert.equal(await page.getByText('Diego Santos').count(), 0)
    assert.equal(await page.getByText('Nina Patel').count(), 0)
  })

  it('hiring manager only sees public engineering candidates', async (t) => {
    const fixture = loadBigBuckFixture()
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl

    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.hiring_manager.email)
    await page.goto(routes.peopleIndex.href())

    const expectedCount = String(fixture.expectations.hiring_manager_count)
    await page.getByText(`${expectedCount} people shown`).waitFor()
    await page.getByText('Ava Chen').waitFor()
    await page.getByText('Victor Lang').waitFor()
    assert.equal(await page.getByText('Kai Nakamura').count(), 0)
    assert.equal(await page.getByText('Rosa Alvarez').count(), 0)
    assert.equal(await page.getByText('Diego Santos').count(), 0)
  })

  it('non-user sees an empty people catalog', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl

    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, api.fixture.users.non_user.email)
    await page.goto(routes.peopleIndex.href())

    await page.getByText('0 people shown').waitFor()
    await page.getByText(/No people visible for this actor/).waitFor()
    assert.equal(await page.getByText('Ava Chen').count(), 0)
  })

  it('home and jobs pages render Big Buck chrome and role-visible jobs', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl

    const page = await t.serve(await createTestServer(router.fetch))
    const qs = ''
    const signInEmail = api.fixture.users.recruiter.email
    await signInAs(page, signInEmail)

    await page.goto(`${routes.home.href()}${qs}`)
    await page.getByRole('heading', { name: 'Big Buck' }).waitFor()
    await page.getByText('Hiring ops').waitFor()
    const commands = page.getByRole('navigation', { name: 'Command actions' })
    for (const label of ['Today', 'Jobs', 'People', 'Interviews', 'Offers', 'Careers', 'Settings']) {
      assert.equal(await commands.getByRole('link', { name: new RegExp(`^${label}`) }).isVisible(), true)
    }
    assert.equal(await commands.getByRole('link', { name: /^Pools/ }).count(), 0)

    await page.goto(`${routes.jobsIndex.href()}${qs}`)
    await page.getByRole('heading', { name: 'Jobs' }).waitFor()
    await page.getByText('Platform Engineer').waitFor()
    await page.getByText('Account Executive').waitFor()
    await page.getByText('2 jobs shown').waitFor()
    await page.getByRole('button', { name: '+ Create' }).waitFor()
  })

  it('pools board, member move, and convert use the REST surface', async (t) => {
    const fixture = loadBigBuckFixture()
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const qs = ''
    const signInEmail = fixture.users.admin.email
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, signInEmail)
    const platform = fixture.projects.find((p) => p.name === 'Platform warm bench')!
    const sam = fixture.people.find((p) => p.key === 'sam')!
    const samMember = fixture.project_members.find((m) => m.person_id === sam.id)!

    await page.goto(`${routes.poolsIndex.href()}${qs}`)
    await page.getByRole('heading', { name: 'Pools' }).waitFor()
    assert.equal(
      await page
        .getByRole('navigation', { name: 'Primary' })
        .getByRole('link', { name: 'People' })
        .getAttribute('aria-current'),
      'page',
    )
    await page.getByText('2 talent pools shown').waitFor()
    await page.getByRole('link', { name: /Platform warm bench/ }).waitFor()
    await page.getByRole('link', { name: /AE talent pool/ }).waitFor()

    await page.goto(`${routes.poolsShow.index.href({ projectId: platform.id })}${qs}`)
    await page.getByRole('heading', { name: 'Platform warm bench' }).waitFor()
    await page.getByRole('heading', { name: 'Sourcing board' }).waitFor()
    await page.getByRole('link', { name: 'Cara Nguyen' }).waitFor()
    await page.getByRole('link', { name: 'Zachary Kim' }).waitFor()
    await page.getByRole('link', { name: 'Sam Okonkwo' }).waitFor()

    await page.goto(`${routes.poolMembersShow.index.href({ memberId: samMember.id })}${qs}`)
    await page.getByRole('heading', { name: 'Sam Okonkwo' }).waitFor()
    await page.getByRole('heading', { name: 'Convert to application' }).waitFor()
    await page.getByRole('button', { name: 'Convert' }).click()
    await page.getByText('Converted to an application on the job.').waitFor()
    await page.getByRole('link', { name: /Open converted application/ }).waitFor()
  })

  it('job pipeline board, application move, and offer detail use the REST surface', async (t) => {
    const fixture = loadBigBuckFixture()
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const qs = ''
    const signInEmail = fixture.users.admin.email
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, signInEmail)
    const engJob = fixture.jobs.find((j) => j.title === 'Platform Engineer')!
    const ava = fixture.people.find((p) => p.key === 'ava')!
    const avaApp = fixture.applications.find((a) => a.person_id === ava.id)!
    const benOffer = fixture.offers.find((o) => o.id.includes('ben'))!

    await page.goto(`${routes.jobsShow.index.href({ jobId: engJob.id })}${qs}`)
    await page.getByRole('heading', { name: 'Platform Engineer' }).waitFor()
    await page.getByRole('link', { name: '← Jobs' }).waitFor()
    const summary = page.getByRole('group', { name: 'Job summary' })
    await summary.getByText('Active').waitFor()
    await summary.getByText('2 openings').waitFor()
    await summary.getByText('Engineering').waitFor()
    const jobNav = page.getByRole('navigation', { name: 'Job' })
    await jobNav.getByRole('link', { name: /^Pipeline/ }).waitFor()
    await jobNav.getByRole('link', { name: /^Applications/ }).waitFor()
    await jobNav.getByRole('link', { name: /^Sourcing/ }).waitFor()
    await jobNav.getByRole('link', { name: /^Settings/ }).waitFor()

    const sections = page.getByRole('navigation', { name: 'Filter by stage group' })
    await sections.getByRole('link', { name: /^Review/ }).waitFor()
    await page.getByRole('link', { name: 'Ava Chen' }).waitFor()
    await page.getByRole('link', { name: 'Ben Ortiz' }).waitFor()
    await page.getByText('5d in stage').first().waitFor()

    const board = page.getByRole('region', { name: 'Pipeline board', exact: true })
    assert.equal(await board.getAttribute('tabindex'), '0')
    await page.setViewportSize({ width: 320, height: 844 })
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true)
    await board.focus()
    await page.keyboard.press('ArrowRight')
    assert.equal(await board.evaluate((el) => el.scrollWidth > el.clientWidth), true)
    await page.setViewportSize({ width: 1280, height: 900 })
    await sections.getByRole('link', { name: /^Onsite/ }).click()
    await page.getByRole('link', { name: 'Ben Ortiz' }).waitFor()
    assert.equal(await page.getByRole('link', { name: 'Ava Chen' }).count(), 0)

    await sections.getByRole('link', { name: /^Offer/ }).click()
    await page.getByRole('link', { name: 'Farah Khan' }).waitFor()

    await sections.getByRole('link', { name: /^Archived/ }).click()
    await page.getByRole('link', { name: 'Tess Bergman' }).waitFor()
    await page.getByText('rejected').first().waitFor()

    await jobNav.getByRole('link', { name: /^Applications/ }).click()
    await page.getByRole('link', { name: 'Ava Chen' }).waitFor()
    await page.getByRole('link', { name: 'Tess Bergman' }).waitFor()

    await jobNav.getByRole('link', { name: /^Sourcing/ }).click()
    await page.getByRole('heading', { name: 'Pools' }).waitFor()
    await page.getByRole('link', { name: 'Platform warm bench' }).waitFor()
    await page.getByRole('heading', { name: 'Rediscovery' }).waitFor()

    await page.getByRole('link', { name: 'Edit pipeline' }).click()
    await page.getByRole('heading', { name: 'Pipeline' }).waitFor()
    await page.getByRole('heading', { name: 'Openings' }).waitFor()
    await page.getByRole('heading', { name: 'Hiring team' }).waitFor()
    await page.locator('.queue-item .title', { hasText: 'Harper Manager' }).waitFor()
    await page.getByRole('textbox', { name: 'Name for Applied' }).waitFor()

    await jobNav.getByRole('link', { name: /^Pipeline/ }).click()
    await sections.getByRole('link', { name: /^Review/ }).click()
    await page.getByRole('radio', { name: 'Select Ava Chen' }).check()
    await page.getByRole('group', { name: 'Move to' }).getByRole('button', { name: 'Onsite' }).click()
    await page.getByText('Move Ava Chen from Applied to Onsite.').waitFor()
    await page.getByRole('button', { name: 'Confirm move' }).click()
    await page.getByText('Moved Ava Chen to Onsite.').waitFor()
    await page.getByRole('link', { name: 'Ava Chen' }).waitFor()
    await page.getByRole('link', { name: 'Ben Ortiz' }).waitFor()

    await page.goto(`${routes.applicationsShow.index.href({ applicationId: avaApp.id })}${qs}`)
    await page.getByRole('heading', { name: 'Ava Chen' }).waitFor()
    await page.locator('summary').filter({ hasText: 'Move candidate' }).click()
    await page.locator('select[name="to_stage_key"]').selectOption('offer')
    await page.getByRole('button', { name: 'Move candidate' }).click()
    await page.getByText('Moved to Offer.').waitFor()
    await page.reload()
    await page.getByRole('heading', { name: 'Ava Chen' }).waitFor()
    assert.equal(await page.getByText('Onsite → Offer', { exact: true }).count(), 1)
    assert.equal(await page.getByRole('alert').count(), 0)

    await page.goto(`${routes.offersShow.index.href({ offerId: benOffer.id })}${qs}`)
    await page.getByRole('heading', { name: 'Offer for Ben Ortiz' }).waitFor()
    await page.getByText('Base Salary', { exact: true }).waitFor()
    await page.getByText('$185,000').waitFor()
    await signInAs(page, fixture.users.hiring_manager.email)
    await page.goto(routes.jobsShow.index.href({ jobId: engJob.id }))
    assert.equal(await page.getByRole('radio').count(), 0)
    assert.equal(await page.getByRole('group', { name: 'Move to' }).count(), 0)
    await page
      .getByRole('navigation', { name: 'Job' })
      .getByRole('link', { name: 'Settings', exact: true })
      .click()
    assert.equal(await page.getByRole('button', { name: 'Save careers settings' }).count(), 0)
    assert.equal(await page.getByRole('button', { name: 'Save openings' }).count(), 0)
  })

  it('interview times are reviewed before booking and refreshing does not book again', async (t) => {
    const fixture = loadBigBuckFixture()
    const ava = fixture.people.find((person) => person.key === 'ava')!
    const application = fixture.applications.find((row) => row.person_id === ava.id)!
    application.current_stage_key = 'onsite'
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.recruiter.email)
    await page.goto(routes.applicationsShow.index.href({ applicationId: application.id }))
    await page
      .getByRole('combobox', { name: 'Interviewer', exact: true })
      .selectOption(fixture.users.recruiter.id)
    await page.locator('input[name="search_date"]').fill('2026-11-05')
    await page.getByRole('button', { name: 'Find interview times' }).click()
    const review = page.getByRole('region', { name: 'Review interview times' })
    await review.getByRole('heading', { name: 'Review interview times' }).waitFor()
    await review.getByText(/Nothing is booked yet/).waitFor()
    assert.equal(await page.locator('details.feedback-interview .feedback-when').count(), 0)
    await review.getByRole('link', { name: 'Cancel', exact: true }).click()
    assert.equal(await page.getByRole('region', { name: 'Review interview times' }).count(), 0)
    assert.equal(await page.locator('details.feedback-interview .feedback-when').count(), 0)
    await page.locator('input[name="search_date"]').fill('2026-11-05')
    await page.getByRole('button', { name: 'Find interview times' }).click()
    await review.getByRole('heading', { name: 'Review interview times' }).waitFor()
    await page.reload()
    await review.getByRole('heading', { name: 'Review interview times' }).waitFor()
    assert.equal(await page.locator('details.feedback-interview .feedback-when').count(), 0)
    const second = review.getByRole('radio').nth(1)
    const selected = await second.locator('..').innerText()
    await second.check()
    await review.getByRole('button', { name: 'Confirm interview booking' }).click()
    await page
      .getByText('Interview booked at the selected time. Submit feedback after the interview.')
      .waitFor()
    await page.locator('details.feedback-interview .feedback-when').waitFor()
    assert.equal(selected.includes('10:00'), true)
    await page.locator('details.feedback-interview .feedback-when', { hasText: /10:00 AM EST/ }).waitFor()
    await page.reload()
    assert.equal(await page.locator('details.feedback-interview .feedback-when').count(), 1)
    assert.equal(await page.getByRole('region', { name: 'Review interview times' }).count(), 0)
  })

  it('create person and create job forms post to the API', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const qs = ''
    const signInEmail = api.fixture.users.admin.email
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, signInEmail)

    await page.goto(`${routes.peopleIndex.href()}${qs}`)
    await page.getByRole('button', { name: '+ Create' }).click()
    await page.getByRole('link', { name: /New person/ }).click()
    await page.getByLabel('Full name').fill('Zed Newperson')
    await page.getByLabel('Email').fill('zed@example.com')
    await page.getByRole('button', { name: 'Create person' }).click()
    await page.getByText(/Created Zed Newperson/).waitFor()
    await page.getByRole('heading', { name: 'Zed Newperson' }).waitFor()

    await page.goto(`${routes.jobsIndex.href()}${qs}`)
    await page.getByRole('button', { name: '+ Create' }).click()
    await page.getByRole('link', { name: /New job/ }).click()
    await page.getByLabel('Title').fill('Design Lead')
    await page.getByRole('button', { name: 'Create job' }).click()
    await page.getByText('Opened Design Lead').waitFor()
    await page.getByRole('heading', { name: 'Design Lead' }).waitFor()
    await page.getByRole('heading', { name: 'Hiring team' }).waitFor()
    await page.goto(`${routes.jobsIndex.href()}${qs}`)
    assert.equal(
      await page
        .getByRole('region', { name: 'Jobs results' })
        .getByRole('link', { name: 'Design Lead', exact: true })
        .count(),
      1,
    )
  })

  it('sequences enroll and admin surfaces render', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const qs = ''
    const signInEmail = api.fixture.users.admin.email
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, signInEmail)

    await page.goto(`${routes.sequencesIndex.href()}${qs}`)
    await page.getByRole('heading', { name: 'Sequences' }).waitFor()
    await page.getByRole('link', { name: /Default outreach/ }).waitFor()
    await page.getByText('Create or enroll', { exact: true }).click()
    await page.getByRole('button', { name: 'Enroll & send' }).click()
    await page.getByText(/Enrolled|Error/).waitFor()

    await page.goto(`${routes.admin.index.href()}${qs}`)
    await page.getByRole('heading', { name: 'Admin' }).waitFor()
    await page.getByRole('heading', { name: 'Config as code' }).waitFor()
    await page.getByText('Example Systems').waitFor()
    await page.getByRole('heading', { name: 'Recent events' }).waitFor()
    await page.getByRole('button', { name: 'Create plan' }).click()
    await page.getByText(/Plan |Error/).waitFor()

    await page.goto(`${routes.login.index.href()}`)
    await page.getByRole('heading', { name: 'Big Buck' }).waitFor()
    await page.getByText('Demo SSO').waitFor()
    await page.getByRole('button', { name: 'Admin' }).waitFor()
    await page.getByRole('button', { name: 'Recruiter' }).waitFor()
    await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
    await page.waitForURL((url) => url.pathname === routes.today.href())
    assert.equal(page.url().includes('actor='), false)
    await page.goto(`${routes.login.index.href()}`)
    await page.getByText('Signed in as').waitFor()
    await page.getByRole('button', { name: 'Sign out' }).click()
    await page.getByRole('button', { name: 'Sign out' }).waitFor({ state: 'detached' })
    await page.getByRole('heading', { name: 'Agent first CRM + ATS', exact: true }).waitFor()
    await page.goto(routes.jobsIndex.href())
    await page.getByRole('heading', { name: 'Sign in to continue' }).waitFor()
  })

  it('header nav never carries identity in the URL', async (t) => {
    const fixture = loadBigBuckFixture()
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const qs = ''
    const signInEmail = fixture.users.recruiter.email
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, signInEmail)

    await page.goto(`${routes.peopleIndex.href()}${qs}`)
    await page.getByText(`${fixture.expectations.recruiter_count} people shown`).waitFor()
    const jobsNav = page.getByRole('navigation', { name: 'Primary' }).getByRole('link', {
      name: 'Jobs',
    })
    assert.equal((await jobsNav.getAttribute('href'))?.includes('org='), false)
    assert.equal((await jobsNav.getAttribute('href'))?.includes('actor='), false)
    await jobsNav.click()
    await page.getByRole('heading', { name: 'Jobs' }).waitFor()
    await page.getByText('2 jobs shown').waitFor()
  })

  it('careers page shows configurable photo hero and openings', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    process.env.BIGBUCK_ORG_SLUG = api.fixture.organization.slug

    const page = await t.serve(await createTestServer(router.fetch))
    await page.goto(`${routes.careersIndex.href()}?slug=${api.fixture.organization.slug}`)

    await page.getByRole('heading', { name: 'Open roles', level: 1 }).waitFor()
    await page.getByText('Build with us at Big Buck.').waitFor()
    assert.equal(await page.locator('source[type="image/avif"]').count(), 1)
    assert.equal(await page.locator('source[type="image/webp"]').count(), 1)
    const hero = page.locator('img[src="/careers-canopy.jpg"]')
    assert.equal(await hero.count(), 1)
    assert.equal(await hero.first().isVisible(), true)
    await page.getByText('Platform Engineer').waitFor()
    await page.getByText('Account Executive').waitFor()
    assert.equal(await page.getByRole('link', { name: /Apply/ }).count(), 2)
  })

  it('today keeps personal interviews and feedback first, with recruiting context alongside', async (t) => {
    const fixture = loadBigBuckFixture()
    const endOfToday = new Date()
    endOfToday.setHours(23, 59, 59, 999)
    fixture.upcoming_interview_starts_at = endOfToday.toISOString()
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, api.fixture.users.admin.email)

    await page.getByRole('heading', { name: 'Today', exact: true }).waitFor()
    const todayInterviews = page.getByRole('region', { name: 'Interviews today' })
    await todayInterviews.getByText('Ava Chen').waitFor()
    assert.equal(await todayInterviews.getByText('Diego Santos').count(), 0)
    assert.equal(
      await todayInterviews.getByRole('link', { name: 'View interview schedule →' }).getAttribute('href'),
      '/interviews?tab=upcoming',
    )
    await page
      .getByRole('region', { name: 'Feedback pending' })
      .getByRole('link', { name: 'Write feedback' })
      .first()
      .waitFor()
    assert.equal(await page.getByRole('region', { name: 'Coming up', exact: true }).count(), 0)
    await page
      .getByRole('region', { name: 'Pipeline', exact: true })
      .getByRole('link', { name: 'Analytics →' })
      .waitFor()
    await page.getByRole('region', { name: 'Offers', exact: true }).getByText('Awaiting approval').waitFor()
    await page.getByRole('link', { name: 'Review applicants →' }).click()
    const applications = page.getByRole('region', { name: 'Applications', exact: true })
    await applications.getByRole('link', { name: 'Review', exact: true }).first().waitFor()
    await applications.getByRole('link', { name: 'All applications →' }).waitFor()

    await page.goto(routes.interviewsIndex.href())
    await page.getByRole('heading', { name: 'Interviews' }).waitFor()
    const show = page.getByRole('navigation', { name: 'Show' })
    assert.equal(await show.getByRole('link', { name: /Upcoming/ }).getAttribute('aria-current'), 'page')
    await page.getByText('Ava Chen').first().waitFor()
    assert.equal(await page.getByText('Diego Santos').count(), 0)
    await page.getByRole('link', { name: 'All' }).click()
    await page.getByText('Diego Santos').waitFor()
    await show.getByRole('link', { name: /To schedule/ }).click()
    await page.getByText('Ben Ortiz').waitFor()
    await show.getByRole('link', { name: /Feedback due/ }).click()
    await page.getByText('Hana').first().waitFor()
    await show.getByRole('link', { name: /My panels/ }).click()
    await page.getByRole('link', { name: 'Open' }).first().waitFor()

    await page.goto(routes.offersIndex.href())
    await page.getByRole('heading', { name: 'Offers' }).waitFor()
    const states = page.getByRole('navigation', { name: 'Offers by state' })
    assert.equal(await states.getByRole('link', { name: /Drafts/ }).getAttribute('aria-current'), 'page')
    const drafts = page.getByRole('region', { name: 'Drafts' })
    await drafts.getByRole('row', { name: /Ben Ortiz/ }).waitFor()
    await states.getByRole('link', { name: /^Approve / }).click()
    await page.waitForURL((url) => url.searchParams.get('tab') === 'pending')
    await page
      .getByRole('navigation', { name: 'Offers by state' })
      .getByRole('link', { name: /^Approve / })
      .waitFor()
    await drafts.getByRole('row', { name: /Ben Ortiz/ }).waitFor({ state: 'hidden' })
    const farah = page.getByRole('region', { name: 'Approve' }).getByRole('row', { name: /Farah Khan/ })
    await farah.waitFor()
    await farah.getByRole('link', { name: 'Open' }).click()
    await page.getByRole('heading', { name: /Offer for/ }).waitFor()
    assert.equal(
      await page
        .getByRole('navigation', { name: 'Primary' })
        .getByRole('link', { name: 'Offers' })
        .getAttribute('aria-current'),
      'page',
    )
  })

  it('theme toggle switches light and dark and remembers the choice', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, api.fixture.users.admin.email)

    const html = page.locator('html')
    assert.equal(await html.getAttribute('data-theme'), null)
    // One sun button: it always offers the other theme, including while following the system.
    await page.emulateMedia({ colorScheme: 'light' })
    await page.getByRole('button', { name: 'Switch to dark theme', exact: true }).click()
    await page.waitForFunction(() => document.documentElement.dataset.theme === 'dark')
    const dark = await page.evaluate(() => getComputedStyle(document.body).backgroundColor)
    assert.equal(await page.getByRole('button', { name: 'Switch to dark theme', exact: true }).count(), 0)

    await page.goto(routes.jobsIndex.href())
    assert.equal(await html.getAttribute('data-theme'), 'dark')

    await page.getByRole('button', { name: 'Switch to light theme', exact: true }).click()
    await page.waitForFunction(() => document.documentElement.dataset.theme === 'light')
    const light = await page.evaluate(() => getComputedStyle(document.body).backgroundColor)
    assert.notEqual(dark, light)
  })

  it('nav only offers areas the role can use', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, api.fixture.users.hiring_manager.email)

    const nav = page.getByRole('navigation', { name: 'Primary' })
    await nav.getByRole('link', { name: 'Jobs' }).waitFor()
    assert.equal(await nav.getByRole('link', { name: 'Admin' }).count(), 0)
    assert.equal(await nav.getByRole('link', { name: 'Pools' }).count(), 0)
    assert.equal(await nav.getByRole('link', { name: 'Branding' }).count(), 0)
  })

  it('agents: create, show a token once, act as the agent and stop', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, api.fixture.users.admin.email)

    await page.goto(routes.settingsAgents.index.href())
    await page.getByRole('heading', { name: 'Agents' }).waitFor()
    await page.getByLabel('Name').fill('Sourcer')
    await page.getByLabel('Read people').check()
    await page.getByRole('button', { name: 'Create agent' }).click()
    await page.getByText('Created Sourcer').waitFor()

    await page.getByRole('button', { name: 'New token' }).click()
    await page.getByText('Copy this token now').waitFor()
    assert.match((await page.getByTestId('new-token').textContent()) ?? '', /^bb_live_/)
    await page.goto(routes.settingsAgents.index.href())
    assert.equal(await page.getByTestId('new-token').count(), 0, 'the token is never shown again')

    await page.getByRole('button', { name: 'Act as this agent' }).click()
    await page
      .getByText(/Acting as Sourcer/)
      .first()
      .waitFor()
    await page.getByText('acting now').waitFor()
    await page.getByRole('button', { name: 'Stop acting' }).click()
    await page.getByText('Back to acting as yourself').waitFor()
  })

  it('custom fields: add a field and archive it without losing it', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, api.fixture.users.admin.email)

    await page.goto(routes.settingsIndex.href())
    await page
      .locator('.settings-directory')
      .getByRole('link', { name: /Custom fields/ })
      .click()
    await page.getByRole('heading', { name: 'Custom fields' }).waitFor()
    await page.getByText('Source', { exact: true }).waitFor()

    await page.getByLabel('Label').fill('Seniority')
    await page.getByLabel(/^Key/).fill('seniority')
    await page.locator('select[name="field_type"]').selectOption('select')
    await page.getByLabel(/^Options/).fill('Junior, Senior')
    await page.getByRole('button', { name: 'Add field' }).click()
    await page.getByText('Added seniority').waitFor()
    await page.getByText(/select · internal · v1 · Junior, Senior/).waitFor()

    await page.getByRole('button', { name: 'Archive' }).first().click()
    await page.getByText(/its values are kept/).waitFor()
    await page.getByRole('button', { name: 'Restore' }).waitFor()
  })

  it('person profile shows custom field details from GraphQL', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, api.fixture.users.admin.email)
    const ava = api.fixture.people.find((p) => p.key === 'ava')!

    await page.goto(routes.peopleShow.index.href({ personId: ava.id }))
    await page.getByRole('link', { name: 'Person details', exact: true }).click()
    await page.getByRole('heading', { name: 'Details' }).waitFor()
    await page.getByText('referral', { exact: true }).waitFor()
  })

  it('anonymous landing offers four interfaces and public documentation', async (t) => {
    const page = await t.serve(await createTestServer(router.fetch))
    await page.goto(routes.home.href())
    await page.getByRole('heading', { name: 'Agent first CRM + ATS', exact: true }).waitFor()
    for (const surface of ['ui', 'mcp', 'api', 'cli'])
      assert.equal(await page.locator(`.lab-card[href*="surface=${surface}"]`).count(), 1)
    assert.equal(
      await page.getByRole('link', { name: 'View the careers site →' }).getAttribute('href'),
      routes.careersIndex.href(),
    )
    await page.getByRole('link', { name: 'Docs', exact: true }).click()
    await page.getByRole('heading', { name: 'A recruiting system you can take apart' }).waitFor()
  })

  it('command search is a GET form and lists role-filtered commands', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, api.fixture.users.recruiter.email)
    await page.getByLabel('Search or jump').fill('people')
    await page.getByRole('button', { name: 'Search' }).click()
    await page.waitForURL((url) => url.pathname === routes.search.href())
    await page.getByRole('heading', { name: 'Search' }).waitFor()
    await page
      .getByRole('link', { name: /^People/ })
      .first()
      .waitFor()
  })

  it('applications, companies, and people who-pills use the shared tables', async (t) => {
    const fixture = loadBigBuckFixture()
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.admin.email)

    await page.goto(routes.applicationsIndex.href())
    await page.getByRole('heading', { name: 'Applications' }).waitFor()
    await page.getByText('Ava Chen').waitFor()
    assert.equal(
      await page
        .getByRole('navigation', { name: 'Primary' })
        .getByRole('link', { name: 'Jobs', exact: true })
        .first()
        .getAttribute('aria-current'),
      'page',
    )

    await page.goto(routes.companiesIndex.href())
    await page.getByRole('heading', { name: 'Companies' }).waitFor()
    await page.getByRole('link', { name: 'Example Systems' }).waitFor()
    assert.equal(
      await page
        .getByRole('navigation', { name: 'Primary' })
        .getByRole('link', { name: 'People' })
        .getAttribute('aria-current'),
      'page',
    )

    await page.goto(routes.peopleIndex.href())
    await page.getByRole('navigation', { name: 'Who' }).getByRole('link', { name: 'Candidates' }).click()
    await page.waitForURL((url) => url.searchParams.get('lifecycle_stage') === 'candidate')
    await page.getByRole('columnheader', { name: 'Hiring' }).waitFor()
    await page.getByRole('columnheader', { name: 'Owner' }).waitFor()
  })

  it('careers page includes culture, a demo note, and structured data', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await page.goto(`${routes.careersIndex.href()}?slug=${api.fixture.organization.slug}`)
    await page.getByText(`Life at ${api.fixture.organization.name}`, { exact: true }).click()
    await page.getByRole('heading', { name: 'How we work' }).waitFor()
    await page.getByRole('heading', { name: 'One record. Every surface.' }).waitFor()
    assert.match(
      (await page.locator('.careers-page').getAttribute('style')) ?? '',
      /--careers-accent:#2ec4b6/,
    )
    await page.getByText('Demo careers page').waitFor()
    assert.equal(await page.locator('script[type="application/ld+json"]').count(), 1)
    await page.goto(routes.careersSitemap.href() + `?slug=${api.fixture.organization.slug}`)
    const body = await page.content()
    assert.match(body, /urlset/)
  })
  it('filtered People returns survive a linked company and search result navigation', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, api.fixture.users.admin.email)
    await page.goto('/people?q=Ava&lifecycle_stage=candidate')
    await page.getByRole('link', { name: 'Ava Chen', exact: true }).click()
    assert.equal(
      await page.getByRole('link', { name: '← People', exact: true }).getAttribute('href'),
      '/people?q=Ava&lifecycle_stage=candidate',
    )
    await page.getByRole('link', { name: 'Person details', exact: true }).click()
    await page.getByText('Link a company', { exact: true }).click()
    await page.getByLabel('Title', { exact: true }).fill('Engineer')
    await page.getByRole('button', { name: 'Link company', exact: true }).click()
    await page.getByText('Person details updated.', { exact: true }).waitFor()
    await page.getByRole('link', { name: '← People', exact: true }).click()
    await page.waitForURL(
      (url) =>
        url.pathname === '/people' &&
        url.searchParams.get('q') === 'Ava' &&
        url.searchParams.get('lifecycle_stage') === 'candidate',
    )
    await page.goto('/search?q=Ava')
    await page
      .getByRole('region', { name: 'People', exact: true })
      .getByRole('link', { name: 'Ava Chen', exact: true })
      .click()
    await page.getByRole('link', { name: '← Search results', exact: true }).click()
    await page.waitForURL((url) => url.pathname === '/search' && url.searchParams.get('q') === 'Ava')
  })

  it('Applications keeps job, stage and page through a stage action and sibling review', async (t) => {
    const fixture = loadBigBuckFixture()
    const template = fixture.applications.find((a) => a.current_stage_key === 'applied')!
    fixture.applications = Array.from({ length: 30 }, (_, index) => ({ ...template, id: `review-${index}` }))
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.admin.email)
    const listUrl = `/applications?job_id=${template.job_id}&stage=applied&page=2`
    await page.goto(listUrl)
    await page
      .getByRole('region', { name: 'Application results' })
      .getByRole('link', { name: 'Ava Chen', exact: true })
      .first()
      .click()
    await page.locator('summary').filter({ hasText: 'Move candidate' }).click()
    await page.getByRole('button', { name: 'Move candidate', exact: true }).click()
    await page.getByText('Moved to Onsite.', { exact: true }).waitFor()
    assert.equal(
      await page.getByRole('link', { name: '← Applications', exact: true }).getAttribute('href'),
      listUrl,
    )
    await page
      .getByRole('navigation', { name: 'Review', exact: true })
      .getByRole('link', { name: /^Next/ })
      .click()
    await page.getByRole('link', { name: '← Applications', exact: true }).click()
    await page.waitForURL(
      (url) =>
        url.pathname === '/applications' &&
        url.searchParams.get('page') === '2' &&
        url.searchParams.get('stage') === 'applied' &&
        url.searchParams.get('job_id') === template.job_id,
    )
  })

  it('record actions reflect role permissions and mobile overflow stays within result tables', async (t) => {
    const fixture = loadBigBuckFixture()
    const ava = fixture.people.find((person) => person.key === 'ava')!
    ava.display_name = 'Ava' + 'LongName'.repeat(24)
    ava.source = 'LongSource'.repeat(40)
    const application = fixture.applications.find((row) => row.person_id === ava.id)!
    application.application_form_snapshot = [
      { key: 'experience', label: 'LongQuestion'.repeat(30), field_type: 'text', required: false },
    ]
    application.application_answers = { experience: 'LongAnswer'.repeat(60) }
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.hiring_manager.email)
    await page.goto(`/people/${ava.id}`)
    await page.getByRole('heading', { name: ava.display_name, exact: true }).waitFor()
    assert.equal(await page.getByRole('button', { name: 'Send email' }).count(), 0)
    assert.equal(await page.getByRole('button', { name: 'Link company', exact: true }).count(), 0)
    assert.equal(await page.getByRole('button', { name: 'Erase person' }).count(), 0)
    await page.goto('/people')
    assert.equal(await page.getByRole('checkbox').count(), 0)
    assert.equal(await page.getByRole('button', { name: 'Review and enroll' }).count(), 0)
    await signInAs(page, fixture.users.admin.email)
    await page.setViewportSize({ width: 320, height: 844 })
    await page.goto('/people')
    const region = page.getByRole('region', { name: 'People results' })
    await region.focus()
    await page.keyboard.press('ArrowRight')
    await page.waitForFunction(
      () => (document.querySelector('[aria-label="People results"]')?.scrollLeft ?? 0) > 0,
    )
    for (const url of [`/people/${ava.id}`, `/applications/${application.id}`]) {
      await page.goto(url)
      await page.getByRole('heading', { name: ava.display_name, exact: true }).waitFor()
      if (url.startsWith('/applications'))
        await page.getByText('Application responses', { exact: true }).click()
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true)
    }
  })
  it('search preserves successful groups during an API failure and retries in query context', async (t) => {
    const fixture = loadBigBuckFixture()
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.admin.email)
    fixture.rest_failures = { '/v1/people': 503 }
    await page.goto('/search?q=Engineer&slug=big-buck')
    await page.getByText('People search is unavailable.', { exact: false }).waitFor()
    await page
      .getByRole('region', { name: 'Jobs', exact: true })
      .getByRole('link', { name: /Engineer/ })
      .first()
      .waitFor()
    assert.equal(await page.getByText('No people match this search.').count(), 0)
    fixture.rest_failures = {}
    await page.getByRole('link', { name: 'Retry search', exact: true }).click()
    await page.waitForURL(
      (url) =>
        url.pathname === '/search' &&
        url.searchParams.get('q') === 'Engineer' &&
        url.searchParams.get('slug') === 'big-buck',
    )
    await page.getByText('No people match this search.').waitFor()
  })
  it('person tabs keep record context and archive only the selected application with a reason', async (t) => {
    const fixture = loadBigBuckFixture()
    const ava = fixture.people.find((person) => person.key === 'ava')!
    const app = fixture.applications.find((application) => application.person_id === ava.id)!
    const second = { ...app, id: 'another-ava-application' }
    fixture.applications.push(second)
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.recruiter.email)
    const url = `/people/${ava.id}?return_to=${encodeURIComponent('/people?q=Ava')}`
    await page.goto(url)
    await page.getByRole('heading', { name: 'Application history 2 shown', exact: true }).waitFor()
    assert.equal(await page.getByRole('region', { name: 'Timeline', exact: true }).count(), 0)
    assert.equal(await page.getByRole('region', { name: 'Resume', exact: true }).count(), 0)
    await page.getByRole('link', { name: 'Person details', exact: true }).click()
    assert.equal(
      await page.getByRole('link', { name: 'Person details', exact: true }).getAttribute('aria-current'),
      'page',
    )
    assert.equal(await page.getByRole('button', { name: 'Erase person', exact: true }).count(), 0)
    await page.getByRole('link', { name: 'Activity', exact: true }).click()
    await page.getByRole('region', { name: 'Timeline', exact: true }).waitFor()
    await page.getByRole('link', { name: 'Application history 2', exact: true }).click()
    const move = page
      .locator('details.record-action-menu')
      .filter({ has: page.locator('summary').filter({ hasText: 'Move candidate' }) })
    await move.locator('summary').click()
    const moveForm = move.locator(`form[data-application-id="${app.id}"]`)
    await moveForm.getByLabel('To stage', { exact: true }).selectOption('onsite')
    await moveForm.getByRole('button', { name: 'Move candidate', exact: true }).click()
    await page.getByText('Moved to Onsite.', { exact: true }).waitFor()
    const invalidReason = await page.request.post(
      new URL(`/people/${ava.id}?tab=applications`, page.url()).href,
      {
        form: { intent: 'archive', application_id: app.id, archive_reason: 'invalid' },
      },
    )
    assert.match(await invalidReason.text(), /Choose a reason to archive this application/)
    const archive = page
      .locator('details.record-action-menu')
      .filter({ has: page.locator('summary').filter({ hasText: 'Archive application' }) })
    await archive.locator('summary').click()

    const form = archive.locator(`form[data-application-id="${app.id}"]`)
    assert.equal(await form.count(), 1)
    await form.getByLabel('Archive reason', { exact: true }).selectOption('not_a_fit')
    await form.getByRole('button', { name: 'Archive application', exact: true }).click()
    await page.getByText('Application archived: Not a fit.', { exact: true }).waitFor()
    await page.getByRole('heading', { name: 'Ava Chen', exact: true }).waitFor()
    await page.getByText('Archived · Rejected', { exact: true }).waitFor()
    await page.getByText('Reason: Not a fit', { exact: true }).waitFor()
    assert.equal(await page.locator('.person-application .chip', { hasText: /^Active$/ }).count(), 1)
    await page.reload()
    await page.getByText('Reason: Not a fit', { exact: true }).waitFor()
    const applicationResult = await page.request.get(
      new URL(`/people/${ava.id}?tab=applications`, page.url()).href,
    )
    assert.equal(applicationResult.status(), 200)
    const rejectedForeign = await page.request.post(
      new URL(`/people/${ava.id}?tab=applications`, page.url()).href,
      {
        form: {
          intent: 'archive',
          application_id: fixture.applications.find((application) => application.person_id !== ava.id)!.id,
          archive_reason: 'withdrew',
        },
      },
    )
    assert.match(await rejectedForeign.text(), /does not belong to this person/)
    await page.setViewportSize({ width: 320, height: 844 })
    await page.reload()
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true)
    await page.locator('summary').filter({ hasText: 'Archive application' }).click()
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true)
    const secondForm = archive.locator('form')
    await secondForm.getByLabel('Archive reason', { exact: true }).selectOption('withdrew')
    await secondForm.getByRole('button', { name: 'Archive application', exact: true }).click()
    await page.getByText('Archived · Withdrawn', { exact: true }).waitFor()
    await page.getByText('Reason: Candidate withdrew', { exact: true }).waitFor()
    await page.getByRole('link', { name: '← People', exact: true }).click()
    await page.waitForURL((url) => url.pathname === '/people' && url.searchParams.get('q') === 'Ava')
    await signInAs(page, fixture.users.hiring_manager.email)
    const denied = await page.request.post(new URL(`/people/${ava.id}`, page.url()).href, {
      form: { intent: 'archive', application_id: app.id, archive_reason: 'not_a_fit' },
    })
    assert.match(await denied.text(), /Application actions are not available/)
    await signInAs(page, fixture.users.admin.email)
    const eraseDenied = await page.request.post(new URL(`/people/${ava.id}?tab=details`, page.url()).href, {
      form: { intent: 'erase' },
    })
    assert.match(await eraseDenied.text(), /Only an owner can erase personal data/)
  })

  it('a bulk action missing its pool keeps the selection and choices', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, api.fixture.users.recruiter.email)
    await page.goto('/people')
    await page.getByRole('checkbox', { name: 'Select Ben Ortiz', exact: true }).check()
    await page.getByRole('button', { name: 'Add selected to pool', exact: true }).click()
    await page.getByText('Could not complete: Choose a pool to add the selected people to.').waitFor()
    assert.equal(new URL(page.url()).pathname, '/people')
    assert.equal(
      await page.getByRole('checkbox', { name: 'Select Ben Ortiz', exact: true }).isChecked(),
      true,
    )
    await page
      .getByRole('combobox', { name: 'Pool to add selected to', exact: true })
      .selectOption({ index: 1 })
    await page.getByRole('button', { name: 'Add selected to pool', exact: true }).click()
    // The success notice survives the redirect back to the list.
    await page.locator('.notice').filter({ hasText: /pool/ }).waitFor()
    // The list filter and the bulk chooser have distinct labels.
    await page.getByRole('combobox', { name: 'Filter by pool', exact: true }).waitFor()
    await page.getByRole('combobox', { name: 'Pool to add selected to', exact: true }).waitFor()
  })

  it('a booked interview opens on its own page with its details and feedback', async (t) => {
    const fixture = loadBigBuckFixture()
    const ava = fixture.people.find((row) => row.key === 'ava')!
    const app = fixture.applications.find((row) => row.person_id === ava.id)!
    app.current_stage_key = 'onsite'
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.recruiter.email)
    await page.goto(`/people/${ava.id}`)
    await page.getByText('Schedule an interview', { exact: true }).click()
    await page
      .getByRole('combobox', { name: 'Interviewer', exact: true })
      .selectOption(fixture.users.recruiter.id)
    await page.locator('input[name="search_date"]').fill('2026-11-06')
    await page.getByRole('button', { name: 'Find interview times', exact: true }).click()
    await page.getByRole('button', { name: 'Confirm interview booking', exact: true }).click()
    await page.getByText(/^Interview booked at the selected time/).waitFor()
    const response = await page.goto('/interviews/interview-1')
    assert.equal(response?.status(), 200)
    assert.equal(new URL(page.url()).pathname, '/interviews/interview-1')
    await page.getByRole('heading', { name: /Recruiter screen · / }).waitFor()
    const details = page.getByRole('region', { name: 'Interview details' })
    await details.getByText('Interviewers', { exact: true }).waitFor()
    await page.getByRole('region', { name: 'Feedback' }).locator('details.feedback-interview').waitFor()
    await page.getByRole('link', { name: 'Open application', exact: true }).waitFor()
    const missing = await page.goto('/interviews/interview-missing')
    assert.equal(missing?.status(), 404)
  })

  it('candidate history supports scheduling and feedback while details and resume stay editable in place', async (t) => {
    const fixture = loadBigBuckFixture()
    const ava = fixture.people.find((row) => row.key === 'ava')!
    const app = fixture.applications.find((row) => row.person_id === ava.id)!
    app.current_stage_key = 'onsite'
    fixture.documents = [
      {
        id: 'current-resume',
        person_id: ava.id,
        filename: 'current.txt',
        content_type: 'text/plain',
        byte_size: 20,
        scan_status: 'clean',
        created_at: new Date().toISOString(),
        downloadable: true,
        content: 'Current resume text',
      },
    ]
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.recruiter.email)
    await page.goto(`/people/${ava.id}?return_to=${encodeURIComponent('/people?q=Ava')}`)
    await page.getByText(/^Schedule Recruiter screen/).waitFor()
    await page.getByText('Schedule an interview', { exact: true }).click()
    await page
      .getByRole('combobox', { name: 'Interviewer', exact: true })
      .selectOption(fixture.users.recruiter.id)
    await page.locator('input[name="search_date"]').fill('2026-11-06')
    await page.getByRole('button', { name: 'Find interview times', exact: true }).click()
    await page.getByRole('region', { name: 'Review interview times', exact: true }).waitFor()
    assert.match(page.url(), /people\/person-ava-0001/)
    await page.getByRole('button', { name: 'Confirm interview booking', exact: true }).click()
    await page
      .getByText('Interview booked at the selected time. Submit feedback after the interview.', {
        exact: true,
      })
      .waitFor()
    await page.reload()
    // Feedback is assigned: the booked interviewer finds their own form open, with the panel listed.
    const feedback = page
      .locator('details.feedback-interview')
      .filter({ has: page.locator('summary').filter({ hasText: 'Recruiter screen' }) })
    await feedback.getByText('Your feedback is due', { exact: true }).waitFor()
    await feedback.getByRole('combobox', { name: 'Overall recommendation', exact: true }).selectOption('yes')
    await feedback.getByLabel('Interview notes', { exact: true }).fill('Strong API experience.')
    await feedback.getByRole('button', { name: 'Submit feedback', exact: true }).click()
    await page.getByText('Feedback submitted.', { exact: true }).waitFor()
    await feedback.getByText('Feedback in', { exact: true }).click()
    await page.getByText('Strong API experience.', { exact: true }).waitFor()
    assert.equal(await feedback.getByRole('button', { name: 'Submit feedback', exact: true }).count(), 0)
    // The author can correct what they submitted; it stays one scorecard.
    await feedback.getByText('Edit your feedback', { exact: true }).click()
    await feedback.getByLabel('Interview notes', { exact: true }).fill('Strong API experience. Hire.')
    await feedback.getByRole('button', { name: 'Save changes', exact: true }).click()
    await page.getByText('Feedback updated.', { exact: true }).waitFor()
    await feedback.getByText('Feedback in', { exact: true }).click()
    await page.getByText('Strong API experience. Hire.', { exact: true }).waitFor()
    assert.equal(await feedback.locator('article.scorecard').count(), 1)
    await signInAs(page, fixture.users.hiring_manager.email)
    await page.goto(`/people/${ava.id}?tab=details`)
    await page.getByText('Edit details', { exact: true }).click()
    const edit = page.locator('details.profile-edit')
    await edit.getByLabel('Full name', { exact: true }).fill('Ava Chen')
    await edit.getByLabel('Email', { exact: true }).fill('ava.updated@example.test')
    await edit.getByLabel('Phone', { exact: true }).fill('+16105550123')
    await edit.getByRole('button', { name: 'Save details', exact: true }).click()
    await page.getByText('Person details updated.', { exact: true }).waitFor()
    await page.reload()
    assert.equal(await page.getByText('ava.updated@example.test', { exact: true }).count(), 2)
    await page.getByText('+16105550123', { exact: true }).waitFor()
    await page.getByRole('link', { name: 'Resume', exact: true }).click()
    await page.getByText('Current resume text', { exact: true }).waitFor()
    assert.equal(await page.getByText('Close resume', { exact: true }).isVisible(), false)
    await page.setViewportSize({ width: 320, height: 844 })
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true)
    await page.locator('input[type="file"]').setInputFiles({
      name: 'replacement.txt',
      mimeType: 'text/plain',
      buffer: Buffer.from('Replacement resume text'),
    })
    await page.getByRole('button', { name: 'Upload resume', exact: true }).click()
    await page
      .getByText('Resume uploaded. It will be available after the security scan.', { exact: true })
      .waitFor()
    await page.getByText('replacement.txt', { exact: true }).waitFor()
    assert.equal(await page.getByText('current.txt', { exact: true }).count(), 0)
    await page.getByText(/Security scan pending/).waitFor()
  })

  it('person and application expose the same resume with private view and download delivery', async (t) => {
    const fixture = loadBigBuckFixture()
    const ava = fixture.people.find((person) => person.key === 'ava')!
    const application = fixture.applications.find((row) => row.person_id === ava.id)!
    fixture.documents = [
      {
        content:
          '%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 6 0 R >>\nendobj\n4 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>\nendobj\n5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n6 0 obj\n<< /Length 56 >>\nstream\nBT /F1 18 Tf 54 720 Td (Ava Chen - Sample resume) Tj ET\nendstream\nendobj\n7 0 obj\n<< /Length 64 >>\nstream\nBT /F1 18 Tf 54 720 Td (Experience - Fictional candidate) Tj ET\nendstream\nendobj\nxref\n0 8\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000121 00000 n \n0000000247 00000 n \n0000000373 00000 n \n0000000443 00000 n \n0000000548 00000 n \ntrailer\n<< /Size 8 /Root 1 0 R >>\nstartxref\n661\n%%EOF\n',
        id: 'resume-ava',
        person_id: ava.id,
        filename: 'ava-resume.pdf',
        content_type: 'application/pdf',
        byte_size: 2048,
        scan_status: 'clean',
        created_at: '2026-11-05T12:00:00Z',
        downloadable: true,
      },
    ]
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.recruiter.email)
    await page.goto(`/people/${ava.id}?tab=resume`)
    const resume = page.getByRole('region', { name: 'Resume', exact: true })
    const view = resume.getByText('View resume', { exact: true })
    const viewer = resume.getByRole('region', { name: 'Resume preview: ava-resume.pdf', exact: true })
    const href = `/people/${ava.id}/documents/resume-ava`
    const recordUrl = page.url()
    await resume.getByText('Page 1 of 2', { exact: true }).waitFor()
    assert.equal(await viewer.isVisible(), true)
    assert.equal(page.url(), recordUrl)
    await resume.getByText('Page 1 of 2', { exact: true }).waitFor()
    await viewer.getByText('Ava Chen - Sample resume', { exact: true }).waitFor()
    await resume.getByRole('button', { name: 'Next resume page', exact: true }).click()
    await resume.getByText('Page 2 of 2', { exact: true }).waitFor()
    await viewer.getByText('Experience - Fictional candidate', { exact: true }).waitFor()
    const beforeZoom = await viewer
      .locator('canvas')
      .evaluate((canvas) => canvas.getBoundingClientRect().width)
    await resume.getByRole('button', { name: 'Zoom resume in', exact: true }).click()
    await page.waitForFunction(
      (width) => document.querySelector('.resume-sheet canvas')!.getBoundingClientRect().width > width,
      beforeZoom,
    )
    await resume.getByRole('button', { name: 'Fit width', exact: true }).click()
    assert.equal(await resume.getByText('Close resume', { exact: true }).isVisible(), false)
    assert.equal(await viewer.isVisible(), true)
    const response = await page.request.get(new URL(href!, page.url()).href)
    assert.equal(response.status(), 200)
    assert.match(response.headers()['content-disposition'], /inline/)
    assert.match(response.headers()['cache-control'], /no-store/)
    assert.match(response.headers()['content-security-policy'], /frame-ancestors 'none'/)
    assert.equal(response.headers()['x-content-type-options'], 'nosniff')
    assert.match(await response.text(), /^%PDF-/)
    const downloadEvent = page.waitForEvent('download')
    await resume.getByRole('link', { name: 'Download resume: ava-resume.pdf', exact: true }).click()
    assert.equal((await downloadEvent).suggestedFilename(), 'ava-resume.pdf')
    await page.goto(`/applications/${application.id}`)
    await view.click()
    await resume.getByText('Page 1 of 2', { exact: true }).waitFor()
    assert.equal(await viewer.isVisible(), true)
    await page.setViewportSize({ width: 320, height: 844 })
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true)
    await resume.getByText('Page 1 of 2', { exact: true }).waitFor()
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true)
    await page.context().clearCookies()
    const anonymous = await page.request.get(new URL(href!, page.url()).href)
    assert.equal(anonymous.status(), 401)
  })

  it('resume distinguishes missing, quarantined and failed loading without hiding the record', async (t) => {
    const fixture = loadBigBuckFixture()
    const ava = fixture.people.find((person) => person.key === 'ava')!
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    await signInAs(page, fixture.users.admin.email)
    await page.goto(`/people/${ava.id}?tab=resume`)
    await page.getByText('No resume attached.', { exact: true }).waitFor()
    fixture.documents = [
      {
        id: 'resume-pending',
        person_id: ava.id,
        filename: 'resume.pdf',
        content_type: 'application/pdf',
        byte_size: 1024,
        scan_status: 'pending',
        created_at: '2026-11-05T12:00:00Z',
        downloadable: false,
      },
    ]
    await page.reload()
    await page.getByText(/Security scan pending/).waitFor()
    assert.equal(await page.getByText('View resume', { exact: true }).count(), 0)
    const blocked = await page.request.get(
      new URL(`/people/${ava.id}/documents/resume-pending`, page.url()).href,
    )
    assert.equal(blocked.status(), 404)
    fixture.rest_failures = { [`/v1/people/${ava.id}/documents`]: 503 }
    await page.reload()
    await page.getByText('Resume could not load. Refresh to try again.', { exact: true }).waitFor()
    assert.equal(await page.getByText('No resume attached.', { exact: true }).count(), 0)
    await page.getByRole('heading', { name: 'Ava Chen', exact: true }).waitFor()
  })
})
