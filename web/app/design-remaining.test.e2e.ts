import * as assert from 'remix/assert'
import { createTestServer } from 'remix/node-fetch-server/test'
import { describe, it } from 'remix/test'

import { loadBigBuckFixture, startMockRailsApi } from '../test/mock-rails-api.ts'
import { router } from './router.ts'

/** Existing router and API fixtures; no separate visual-review server or dataset. */
describe('remaining design workflows', () => {
  it('keeps recruiter and settings tasks reachable through narrow navigation and fallback fonts', async (t) => {
    const fixture = loadBigBuckFixture()
    fixture.rest_responses = {
      '/v1/requisitions': { data: [] },
      '/v1/referrals': { data: [] },
      '/v1/analytics/funnel': { total_applications: 0, hired: 0, rejected: 0, active_by_stage: {} },
      '/v1/analytics/sourcing': {
        active_sequences: 0,
        outbound_messages: 0,
        inbound_replies: 0,
        reply_rate: 0,
      },
    }
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await page.route(/https:\/\/fonts\.(googleapis|gstatic)\.com\//, (route) => route.abort())
    await page.goto('/session/login')
    await page.getByLabel('Work email').fill(api.fixture.users.admin.email)
    await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
    await page.waitForURL('**/today')
    const paths = [
      '/pools',
      '/pools/new',
      '/interviews',
      '/offers',
      '/sequences',
      '/companies',
      '/requisitions',
      '/referrals',
      '/analytics',
      '/settings',
      '/settings/templates',
      '/settings/question-templates',
      '/settings/application-form',
      '/settings/mailboxes',
      '/settings/calendar',
      '/settings/import',
      '/settings/webhooks',
      '/settings/agents',
      '/settings/keys',
      '/settings/fields',
      '/settings/careers',
      '/admin',
    ]
    for (const width of [1280, 320]) {
      await page.setViewportSize({ width, height: 844 })
      for (const path of paths) {
        const response = await page.goto(path)
        assert.equal(response?.status(), 200, path)
        await page.getByRole('heading', { level: 1 }).waitFor()
        assert.ok(
          await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
          `${path} overflows at ${width}`,
        )
      }
    }
    for (const path of ['/interviews', '/settings/agents', `/careers?slug=${fixture.organization.slug}`]) {
      for (const width of [599, 601, 819, 821, 959, 961]) {
        await page.setViewportSize({ width, height: 844 })
        await page.goto(path)
        assert.ok(
          await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
          `${path} at breakpoint ${width}`,
        )
      }
      await page.setViewportSize({ width: 1280, height: 900 })
      await page.goto(path)
      await page.evaluate(() => {
        const elements = [...document.querySelectorAll<HTMLElement>('body, body *')].filter(
          (node) => !['STYLE', 'SCRIPT', 'SVG', 'PATH'].includes(node.tagName),
        )
        const sizes = elements.map((node) => parseFloat(getComputedStyle(node).fontSize))
        elements.forEach((node, index) => {
          node.style.fontSize = `${sizes[index]! * 2}px`
        })
      })
      assert.ok(
        await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
        `${path} with doubled text`,
      )
    }
    await page.setViewportSize({ width: 320, height: 844 })
    await page.goto('/settings/templates')
    await page
      .getByRole('navigation', { name: 'Settings sections', exact: true })
      .getByRole('link', { name: 'Calendar', exact: true })
      .click()
    await page.getByRole('heading', { name: 'Calendar', exact: true }).waitFor()
    await page.getByLabel('Calendar id').fill('team-calendar')
    await page.getByLabel('Secret reference').fill('sm://demo')
    await page.getByRole('button', { name: 'Connect calendar', exact: true }).click()
    await page.getByRole('alert').waitFor()
    assert.equal(await page.getByLabel('Calendar id').inputValue(), 'team-calendar')
    assert.equal(await page.getByLabel('Secret reference').inputValue(), '')
    assert.equal(await page.getByRole('heading', { name: 'Calendar', exact: true }).count(), 1)
    await page.goto('/sequences')
    assert.equal(await page.getByRole('button', { name: 'Enroll & send' }).isVisible(), false)
    await page.getByText('Create or enroll', { exact: true }).click()
    assert.equal(await page.getByRole('button', { name: 'Enroll & send' }).isVisible(), true)
    // Font-service failure must not prevent navigation, editing, or the shared system fallback.
    assert.ok(await page.evaluate(() => getComputedStyle(document.body).fontFamily.includes('sans-serif')))
    assert.equal(await page.evaluate(() => document.fonts.size), 0)
  })

  it('recovers search input and focus entered before browser enhancement is ready', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await page.goto('/session/login')
    await page.getByLabel('Work email').fill(api.fixture.users.admin.email)
    await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
    await page.waitForURL('**/today')
    let release!: () => void
    const ready = new Promise<void>((resolve) => {
      release = resolve
    })
    t.after(() => release())
    await page.route('**/assets/**', async (route) => {
      await ready
      await route.continue()
    })
    await page.goto('/jobs', { waitUntil: 'commit' })
    const search = page.getByRole('searchbox', { name: 'Search or jump' })
    await search.fill('New talent pool')
    release()
    await page.locator('.command-bar[data-enhanced]').waitFor({ state: 'attached' })
    const suggestions = page.getByRole('list', { name: 'Suggested destinations' })
    await suggestions.getByRole('link', { name: /New talent pool/ }).waitFor()
    assert.equal(await search.inputValue(), 'New talent pool')
    assert.equal(await search.evaluate((node) => node === document.activeElement), true)
  })

  it('keeps public token states and application tasks readable without accepting an unusable offer', async (t) => {
    const fixture = loadBigBuckFixture()
    fixture.public_offers = {
      valid: {
        status: 'sent',
        usable: true,
        letter_html: '<h2>Welcome to Example</h2><p>Your role and terms.</p>',
        organization: { name: 'Example Hiring', slug: 'example' },
      },
      expired: { status: 'sent', usable: false },
      complete: { status: 'accepted', usable: false },
    }
    fixture.public_scheduling = { expired: { usable: false, kind: 'self_schedule' } }
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    for (const colorScheme of ['light', 'dark'] as const) {
      await page.emulateMedia({ colorScheme })
      for (const width of [1280, 390, 320]) {
        await page.setViewportSize({ width, height: 844 })
        for (const path of [
          '/offers/valid',
          '/offers/expired',
          '/offers/complete',
          '/offers/missing',
          '/scheduling/mock-scheduling-token',
          '/scheduling/expired',
        ]) {
          await page.goto(path)
          await page.getByRole('heading', { level: 1 }).waitFor()
          assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), path)
          if (path === '/offers/valid') {
            await page.getByRole('link', { name: 'Example Hiring' }).waitFor()
            assert.equal(await page.getByRole('button', { name: 'Accept offer' }).isVisible(), true)
          } else if (path.startsWith('/offers/')) {
            assert.equal(await page.getByRole('button', { name: 'Accept offer' }).count(), 0)
          }
        }
      }
    }
    await page.goto('/offers/valid')
    // Only the disposable API fixture receives this simulated acceptance.
    await page.getByLabel('Type your full name to accept').fill('Example Candidate')
    await page.getByRole('button', { name: 'Accept offer' }).click()
    await page.getByRole('heading', { name: 'Offer accepted' }).waitFor()
    assert.equal(fixture.public_offers.valid!.usable, false)
    assert.equal(await page.getByRole('button', { name: 'Accept offer' }).count(), 0)
  })
})
