import { chromium, devices, type Page } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'

// Phone-sized pass over the product pages (Chromium mobile emulation of an iPhone 13, 390x844, touch).
// Reports horizontal overflow, elements running off-screen, and small touch targets per page, and saves a
// screenshot of each. Read-only: it signs in and visits pages, never submits a form. Start Rails + web first
// (LOCAL_LAB.md). LAB_URL overrides the address; MOBILE_OUT the output folder.
const base = process.env.LAB_URL ?? 'http://127.0.0.1:44100'
const out = process.env.MOBILE_OUT ?? '../tmp/mobile-audit'
const strict = process.env.STRICT === '1'
await mkdir(out, { recursive: true })
const browser = await chromium.launch({ headless: true })

type Report = {
  page: string
  url: string
  overflow: number
  offscreen: string[]
  smallTargets: string[]
  errors: string[]
}
const reports: Report[] = []

async function context(persona?: string) {
  const ctx = await browser.newContext({ ...devices['iPhone 13'], colorScheme: 'light' })
  const page = await ctx.newPage()
  page.setDefaultTimeout(30_000)
  if (persona) {
    await page.goto(`${base}/session?surface=ui&mode=explore`)
    await page
      .getByRole('button', { name: new RegExp(persona) })
      .first()
      .click()
    await page.waitForURL('**/today')
  }
  return page
}

// Measure the page as rendered. Anything inside a deliberate horizontal scroller (overflow-x auto/scroll)
// is allowed to extend past the viewport; everything else must fit.
async function inspect(page: Page, name: string) {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  await page.waitForLoadState('networkidle').catch(() => {})
  const result = await page.evaluate(() => {
    const vw = innerWidth
    const label = (el: Element) => {
      const text = (el.getAttribute('aria-label') || (el as HTMLElement).innerText || '').trim()
      const cls = typeof el.className === 'string' ? el.className.split(' ')[0] : ''
      return `${el.tagName.toLowerCase()}${cls ? '.' + cls : ''} "${text.slice(0, 40).replace(/\s+/g, ' ')}"`
    }
    const inScroller = (el: Element) => {
      for (let p = el.parentElement; p; p = p.parentElement) {
        const s = getComputedStyle(p)
        if (/(auto|scroll|hidden|clip)/.test(s.overflowX) && p.scrollWidth > p.clientWidth) return true
      }
      return false
    }
    const offscreen: string[] = []
    for (const el of document.querySelectorAll('body *')) {
      const r = el.getBoundingClientRect()
      if (r.width === 0 || r.height === 0) continue
      if (getComputedStyle(el).position === 'fixed') continue
      if (r.right > vw + 1 && !inScroller(el)) {
        // Report the outermost offender only.
        const parent = el.parentElement?.getBoundingClientRect()
        if (!parent || parent.right <= vw + 1) offscreen.push(`${label(el)} right=${Math.round(r.right)}`)
      }
    }
    const smallTargets: string[] = []
    for (const el of document.querySelectorAll(
      'a[href], button, select, input:not([type=hidden]), summary',
    )) {
      const r = el.getBoundingClientRect()
      if (r.width === 0 || r.height === 0) continue
      // Inline text links inside prose are exempt (WCAG 2.5.8 inline exception).
      if (el.tagName === 'A' && getComputedStyle(el).display === 'inline' && el.closest('p, li, td')) continue
      if (r.height < 32 || r.width < 32)
        smallTargets.push(`${label(el)} ${Math.round(r.width)}x${Math.round(r.height)}`)
    }
    return {
      overflow: document.documentElement.scrollWidth - vw,
      offscreen: offscreen.slice(0, 12),
      smallTargets,
    }
  })
  await page.screenshot({ path: `${out}/${name}.png` })
  await page.screenshot({ path: `${out}/${name}-full.png`, fullPage: true })
  reports.push({ page: name, url: page.url().replace(base, ''), ...result, errors })
}

async function visit(page: Page, name: string, path: string) {
  await page.goto(`${base}${path}`)
  await inspect(page, name)
}

async function firstHref(page: Page, selector: string) {
  const link = page.locator(selector).first()
  if (!(await link.count())) return null
  return link.getAttribute('href')
}

try {
  const riley = await context('Riley Recruiter')
  await inspect(riley, 'today')
  await visit(riley, 'jobs', '/jobs')
  const job = await firstHref(riley, 'main a[href^="/jobs/0"]')
  if (job) {
    const path = job.split('?')[0]
    await visit(riley, 'job-overview', path)
    await visit(riley, 'job-pipeline', `${path}?tab=pipeline`)
    await visit(riley, 'job-applications', `${path}?tab=applications`)
    await visit(riley, 'job-settings', `${path}/settings`)
  }
  await visit(riley, 'people', '/people')
  const person = await firstHref(riley, 'main a[href^="/people/0"]')
  if (person) await visit(riley, 'person', person)
  await visit(riley, 'applications', '/applications')
  const application = await firstHref(riley, 'main a[href^="/applications/0"]')
  if (application) await visit(riley, 'application', application)
  await visit(riley, 'interviews', '/interviews')
  await visit(riley, 'offers', '/offers')
  const offer = await firstHref(riley, 'main a[href^="/offers/0"]')
  if (offer) await visit(riley, 'offer', offer)
  await visit(riley, 'sequences', '/sequences')
  await visit(riley, 'requisitions', '/requisitions')
  await visit(riley, 'search', '/search?q=platform')
  await visit(riley, 'settings', '/settings')
  await visit(riley, 'settings-team', '/settings/team')

  // The navigation drawer / menu, if the layout collapses one on phones.
  await riley.goto(`${base}/today`)
  const menu = riley.getByRole('button', { name: /menu|navigation/i }).first()
  if (await menu.isVisible().catch(() => false)) {
    await menu.tap()
    await inspect(riley, 'nav-open')
  }

  const visitor = await context()
  await visit(visitor, 'careers', '/careers?slug=big-buck-lab-ui')
  const apply = await firstHref(visitor, 'main a[href*="apply"]')
  if (apply) await visit(visitor, 'careers-apply', apply)
} finally {
  await writeFile(`${out}/results.json`, JSON.stringify(reports, null, 2))
  await browser.close()
}

let failures = 0
for (const r of reports) {
  const bad = r.overflow > 0 || r.offscreen.length > 0 || r.errors.length > 0
  if (bad) failures++
  console.log(
    `${bad ? 'FAIL' : 'ok  '} ${r.page.padEnd(18)} overflow=${r.overflow}px offscreen=${r.offscreen.length} small-targets=${r.smallTargets.length} errors=${r.errors.length}`,
  )
  for (const o of r.offscreen) console.log(`       off-screen: ${o}`)
  for (const e of r.errors) console.log(`       error: ${e}`)
}
console.log(`${reports.length} pages, ${failures} with layout problems. Screenshots in ${out}`)
if (strict && failures) process.exit(1)
