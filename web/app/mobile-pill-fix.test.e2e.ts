import { mkdirSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

import * as assert from 'remix/assert'
import { createTestServer } from 'remix/node-fetch-server/test'
import { describe, it } from 'remix/test'

import { router } from './router.ts'
import { routes } from './routes.ts'
import { loadBigBuckFixture, startMockRailsApi } from '../test/mock-rails-api.ts'

// DESIGN.md: on narrow screens every filter, tab and view row is one sideways-scrolling line. This test
// measures every such row on every page it visits, whether or not the page opted in to anything, so a new
// or forgotten row fails here instead of shipping. Screenshots go to a temp directory for review.
const OUT = process.env.PILL_SHOTS_DIR ?? join(tmpdir(), 'mobile-pill-rows')

type PageLike = {
  setDefaultTimeout(timeout: number): void
  setViewportSize(size: { width: number; height: number }): Promise<void>
  goto(url: string): Promise<unknown>
  getByLabel(label: string): { fill(v: string): Promise<void> }
  getByRole(role: 'button', opts: { name: string }): { click(): Promise<void> }
  waitForURL(url: (url: URL) => boolean): Promise<void>
  waitForLoadState(state: string): Promise<void>
  evaluate(fn: (() => unknown) | string): Promise<unknown>
  screenshot(opts: { path: string }): Promise<unknown>
}

async function signInAs(page: PageLike, email: string) {
  page.setDefaultTimeout(15_000)
  await page.goto(routes.login.index.href())
  await page.getByLabel('Work email').fill(email)
  await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
  await page.waitForURL((url) => url.pathname === routes.today.href())
}

type Measurement = {
  rows: Array<{
    label: string
    kids: number
    visualRows: number
    tops: string
    scrolls: boolean
    currentHidden: boolean
  }>
  thWrapped: string[]
  docOverflow: number
  navGap: number
}

async function measure(page: PageLike) {
  return (await page.evaluate(() => {
    const rows: Measurement['rows'] = []
    // Filters, tabs and views: section tabs, filter segments, step tracks, pagination. Summary chips (div.chip-row) are not filters.
    for (const el of document.querySelectorAll('.tabs, .filter-segments, .step-track, .list-pagination')) {
      const kids = [...el.children] as HTMLElement[]
      // A wrapped row starts a new line a whole control-height lower; sub-pixel and border offsets do not count.
      const tops = kids.map((k) => k.getBoundingClientRect().top).sort((a, b) => a - b)
      let lines = 0
      let lineTop = -Infinity
      for (const top of tops) {
        if (top - lineTop > 12) {
          lines += 1
          lineTop = top
        }
      }
      const box = el.getBoundingClientRect()
      const cur = el.querySelector('[aria-current]')?.getBoundingClientRect()
      rows.push({
        label: el.getAttribute('aria-label') ?? el.className,
        kids: kids.length,
        visualRows: lines,
        tops: tops.map((t) => Math.round(t)).join(','),
        scrolls: el.scrollWidth > el.clientWidth + 1,
        // The current choice must start in view inside a scrolling row (revealCurrentChoices in entry.ts).
        currentHidden: Boolean(cur && (cur.left < box.left - 1 || cur.right > box.right + 1)),
      })
    }
    const thWrapped: string[] = []
    for (const th of document.querySelectorAll('.table th')) {
      const el = th as HTMLElement
      // Single-line headers are 40px tall (forced cell height); a wrapped header is ~51px.
      if (el.offsetHeight > 46) thWrapped.push(el.textContent?.trim() ?? '')
    }
    // Short pages must not stretch the nav row: content starts right under the nav.
    const nav = document.querySelector('.app-nav')
    const main = document.querySelector('main')
    const navGap =
      nav && main ? Math.round(main.getBoundingClientRect().top - nav.getBoundingClientRect().bottom) : 0
    return { rows, thWrapped, docOverflow: document.documentElement.scrollWidth - innerWidth, navGap }
  })) as Measurement
}

describe('Mobile filter rows', () => {
  it('every filter, tab and view row is a single line at 390px', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const fixture = loadBigBuckFixture()
    const jobId = fixture.jobs[0]?.id ?? ''
    const applicationId = fixture.applications[0]?.id ?? ''
    const page = (await t.serve(await createTestServer(router.fetch))) as unknown as PageLike
    await signInAs(page, api.fixture.users.recruiter.email)
    await page.setViewportSize({ width: 390, height: 844 })
    mkdirSync(OUT, { recursive: true })

    const cases: Array<{ name: string; href: string; selectLast?: string }> = [
      { name: 'today', href: routes.today.href() },
      { name: 'applications', href: routes.applicationsIndex.href() },
      { name: 'application-detail', href: routes.applicationsShow.index.href({ applicationId }) },
      { name: 'jobs', href: routes.jobsIndex.href() },
      { name: 'job-board', href: `${routes.jobsShow.index.href({ jobId })}?tab=pipeline` },
      { name: 'job-settings', href: `${routes.jobsShow.index.href({ jobId })}?tab=settings` },
      { name: 'interviews', href: routes.interviewsIndex.href() },
      { name: 'offers', href: routes.offersIndex.href() },
      // The last of nine state pills selected: it starts past the right edge unless the row reveals it.
      { name: 'offers-last-state', href: routes.offersIndex.href(), selectLast: 'Offers by state' },
      { name: 'people', href: routes.peopleIndex.href() },
      { name: 'companies', href: routes.companiesIndex.href() },
      { name: 'pools', href: '/pools' },
      { name: 'tasks', href: '/tasks' },
      { name: 'proposals', href: '/proposals' },
      { name: 'rediscovery', href: '/rediscovery' },
      { name: 'admin', href: '/admin' },
      { name: 'settings-fields', href: routes.settingsFields.index.href() },
    ]

    let rowsChecked = 0
    for (const c of cases) {
      await page.goto(c.href)
      if (c.selectLast) {
        const label = c.selectLast
        const last = (await page.evaluate(
          `document.querySelector('[aria-label="${label}"]').lastElementChild.getAttribute('href')`,
        )) as string
        await page.goto(last)
      }
      await page.waitForLoadState('networkidle').catch(() => {})
      const m = await measure(page)
      await page.screenshot({ path: join(OUT, `${c.name}.png`) })
      assert.equal(m.docOverflow, 0, `${c.name}: no page-level horizontal overflow`)
      assert.ok(m.navGap <= 1, `${c.name}: content starts under the nav, gap ${m.navGap}px`)
      for (const row of m.rows) {
        if (row.kids < 2) continue
        rowsChecked += 1
        assert.equal(
          row.visualRows,
          1,
          `${c.name} [${row.label}]: one visual row, got ${row.visualRows} (tops ${row.tops})`,
        )
        assert.equal(row.currentHidden, false, `${c.name} [${row.label}]: current choice starts in view`)
      }
      assert.deepEqual(m.thWrapped, [], `${c.name}: no wrapped table headers`)
    }
    assert.ok(rowsChecked >= 15, `expected to measure many filter rows, measured ${rowsChecked}`)
  })
})
