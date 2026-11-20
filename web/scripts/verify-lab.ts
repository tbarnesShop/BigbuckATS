import { chromium } from 'playwright'
import assert from 'node:assert/strict'
import { mkdir, writeFile } from 'node:fs/promises'

// Live acceptance checks against disposable registered demo tenants. Start Rails + web first.
const base = process.env.LAB_URL ?? 'http://127.0.0.1:44100'
const browser = await chromium.launch({ headless: process.env.CI === 'true' })
const context = await browser.newContext({
  viewport: { width: 1440, height: 1000 },
  permissions: ['clipboard-read', 'clipboard-write'],
})
const page = await context.newPage()
const errors: string[] = []
page.on('pageerror', (error) => errors.push(error.message))
async function selectedOperation(name: string) {
  // A visible SSR control can precede the client entry applying its value.
  await page.waitForFunction(
    (expected) => (document.querySelector('#operation') as HTMLSelectElement | null)?.value === expected,
    name,
  )
}
async function start(surface: string, mode = 'explore', persona = 'Big Buck Owner') {
  await page.goto(`${base}/session?surface=${surface}&mode=${mode}`)
  await page.getByRole('button', { name: new RegExp(persona) }).click()
  if (surface === 'ui') {
    await page.waitForURL('**/today')
    await page.getByRole('heading', { name: 'Today', exact: true }).waitFor()
    return
  }
  await page.waitForURL(/\/lab(?:\?|$)/)
  await page
    .getByRole('heading', {
      name: `${surface.toUpperCase()} lab`,
    })
    .waitFor()
  if (surface === 'api' || surface === 'mcp')
    await selectedOperation(
      mode === 'compare'
        ? 'listPeople'
        : surface === 'mcp' && mode === 'explore'
          ? 'gql_whoami'
          : 'createPerson',
    )
}
async function run() {
  const response = page.waitForResponse(
    (response) => response.url().endsWith('/lab/execute') && response.request().method() === 'POST',
  )
  await page.getByRole('button', { name: /^(Send request|Run tool|Run command) →$/ }).click()
  const data = await (await response).json()
  assert.equal(data.ok, true, JSON.stringify(data.output))
  await page
    .getByRole('button', { name: /^(Send request|Run tool|Run command) →$/ })
    .waitFor({ state: 'visible' })
  return data
}
async function verifyMovement() {
  const observations: unknown[] = []
  const observe = async (transition: string) =>
    observations.push({
      transition,
      ...(await page.evaluate(() => ({
        url: location.pathname + location.search,
        scrollY,
        focus: document.activeElement?.tagName,
        operation: (document.querySelector('#operation') as HTMLSelectElement | null)?.value,
        resultVisible: !!document.querySelector('.result-panel'),
      }))),
    })
  await start('api')
  await page.locator('#operation').selectOption('listPeople')
  await page.getByLabel('limit', { exact: false }).fill('2')
  await page.getByText('Draft recovery', { exact: true }).click()
  await page.getByRole('checkbox', { name: 'Remember disposable sample inputs in this tab' }).check()
  const send = page.getByRole('button', { name: 'Send request →', exact: true })
  await send.scrollIntoViewIfNeeded()
  await send.focus()
  await observe('Run ready')
  const before = await page.evaluate(() => scrollY)
  await run()
  await page.locator('.result-panel').waitFor()
  await observe('Run completed')
  assert.ok(Math.abs((await page.evaluate(() => scrollY)) - before) <= 2, 'Completion moved the document')
  // Focus without scrolling separates local rendering from browser input actionability.
  const story = page.getByRole('button', { name: /Create a sample person/ })
  await story.evaluate((element) => (element as HTMLElement).focus({ preventScroll: true }))
  await observe('Story focused without scrolling')
  await page.keyboard.press('Enter')
  await observe('Story selected; existing output baseline')
  await page.goto(`${base}/lab?surface=api&mode=explore&operation=listPeople`)
  await page.locator('#operation').waitFor()
  await page.goto(`${base}/docs/interop`)
  await page.goBack()
  assert.equal(await page.locator('#operation').inputValue(), 'listPeople')
  assert.equal(await page.locator('.result-panel').count(), 0, 'History reran a request')
  await observe('Back restored URL selection without execution')
  await page.goForward()
  await page.getByRole('heading', { name: 'Different interfaces. Shared meaning.' }).waitFor()
  await page.goBack()
  // Deterministic expiry response; never reset the shared live sandbox.
  await page.route('**/lab/status', (route) =>
    route.fulfill({
      status: 409,
      contentType: 'application/json',
      body: JSON.stringify({ code: 'sandbox_expired', error: 'P0 simulated generation expiry' }),
    }),
  )
  await page
    .getByRole('alert')
    .filter({ hasText: 'The shared workspace refreshed.' })
    .waitFor({ timeout: 12000 })
  assert.equal(await send.isDisabled(), true)
  await observe('Simulated expiry disables execution')
  await page.unroute('**/lab/status')
  await page.getByRole('link', { name: 'Choose a persona and start again →' }).click()
  // Expiry deliberately clears stored recovery; explicitly discard this disposable fixture draft.
  await page.getByRole('dialog').getByRole('button', { name: 'Discard and continue' }).click()
  await page.getByRole('button', { name: /Big Buck Owner/ }).click()
  await send.waitFor()
  await selectedOperation('createPerson')
  assert.equal(await send.isEnabled(), true)
  await observe('Persona recovery')
  await writeFile(
    '../tmp/lab-verification/movement.json',
    JSON.stringify({ browser: browser.version(), runtime: process.version, observations }, null, 2),
  )
  console.log('PASS completion position, URL history without execution, simulated expiry/recovery')
}
try {
  await mkdir('../tmp/lab-verification', { recursive: true })
  await verifyMovement()
  await page.goto(`${base}/session`)
  assert.equal(await page.locator('.lab-card').count(), 4)
  await page.screenshot({ path: '../tmp/lab-verification/lab-desktop.png', fullPage: true })
  await start('api', 'connect')
  const person = await run()
  const personId = person.output.id
  assert.ok(personId)
  assert.ok(person.example.includes('\n'))
  assert.match(person.example, /<your-credential>/)
  await page.getByRole('link', { name: 'Continue in MCP →', exact: true }).click()
  await page.getByRole('button', { name: 'Run tool →' }).waitFor()
  await selectedOperation('gql_person')
  assert.equal(await page.locator('#operation').inputValue(), 'gql_person')
  const inspected = await run()
  assert.equal(inspected.output.data.person.id, personId)
  await page.getByRole('link', { name: 'Continue in CLI →', exact: true }).first().click()
  await page.getByLabel('Command', { exact: true }).waitFor()
  assert.match(await page.getByLabel('Command', { exact: true }).inputValue(), /project create/)
  const pool = await run()
  await page.getByRole('button', { name: /Make a talent pool/ }).waitFor()
  await page.getByRole('button', { name: /Add the person to your pool/ }).click()
  assert.match(await page.getByLabel('Command', { exact: true }).inputValue(), new RegExp(personId))
  const member = await run()
  assert.equal(member.output.person_id, personId)
  assert.equal(member.output.project_id, pool.output.id)
  await page.getByRole('link', { name: 'Continue in UI →', exact: true }).first().click()
  await page.waitForURL(new RegExp(`/people/${personId}`))
  await page.getByRole('heading', { name: person.output.display_name, exact: true }).waitFor()
  console.log('PASS real API → MCP → CLI → UI continuity')
  await start('cli')
  for (const step of [
    'Create configuration files',
    'Inspect a configuration plan',
    'Apply the plan',
    'Preview a CSV import',
    'Import the contacts',
  ]) {
    await page.getByRole('button', { name: new RegExp(step) }).click()
    const result = await run()
    if (step === 'Preview a CSV import') assert.equal(result.output.status, 'dry_run')
    if (step === 'Import the contacts') assert.equal(result.output.status, 'applied')
  }
  console.log('PASS real CLI files, configuration plan/apply, CSV preview/import')
  const organizations = new Set<string>()
  for (const surface of ['api', 'mcp', 'cli']) {
    await start(surface, 'compare')
    await page.getByRole('button', { name: /Find someone already here/ }).click()
    await run()
    await page.getByRole('button', { name: /Make a talent pool/ }).click()
    const pool = await run()
    organizations.add(pool.output.organization_id)
    await page.getByRole('button', { name: /Add the person to your pool/ }).click()
    const member = await run()
    assert.equal(member.output.project_id, pool.output.id)
  }
  await start('ui', 'compare')
  await page.goto(`${base}/lab?surface=ui&mode=compare&step=pool`)
  await page.getByRole('heading', { name: 'New talent pool', exact: true }).waitFor()
  assert.match(await page.getByLabel('Name', { exact: true }).inputValue(), /Lab pool/)
  await page.getByRole('button', { name: 'Create pool', exact: true }).click()
  await page.getByText(/Opened Lab pool/).waitFor()
  await page.goto(`${base}/lab?surface=ui&mode=compare&step=member`)
  await page.getByText('Add to pool', { exact: true }).click()
  await page.getByLabel('Person', { exact: true }).waitFor()
  const ava = await page
    .getByLabel('Person', { exact: true })
    .locator('option')
    .filter({ hasText: 'Ava Chen' })
    .getAttribute('value')
  assert.ok(ava)
  await page.getByLabel('Person', { exact: true }).selectOption(ava!)
  await page.getByRole('button', { name: 'Add member', exact: true }).click()
  await page.getByText('Member added', { exact: true }).waitFor()
  assert.equal(organizations.size, 3)
  console.log('PASS Compare task through all four interfaces')
  await page.goto(`${base}/session?surface=ui&mode=explore`)
  await page.getByRole('button', { name: /Riley Recruiter/ }).click()
  await page.waitForURL('**/today')
  await page.getByRole('heading', { name: 'Today', exact: true }).waitFor()
  await page.getByRole('link', { name: 'Back to lab', exact: true }).click()
  await page.waitForURL('**/session')
  assert.equal(await page.locator('.lab-card').count(), 4)
  console.log('PASS direct UI Explore handoff and return to lab entry')
  await start('cli')
  await page.goto(`${base}/docs/agents`)
  await page.getByRole('heading', { name: 'An agent is someone acting for someone' }).waitFor()
  await page.getByRole('button', { name: 'Copy', exact: true }).first().click()
  assert.match(await page.evaluate(() => navigator.clipboard.readText()), /effective permissions/)
  await page.getByLabel('Search the docs').fill('legal hold')
  assert.ok(
    await page
      .getByRole('navigation', { name: 'Documentation' })
      .getByRole('link', { name: 'Privacy & compliance' })
      .isVisible(),
  )
  await page.getByLabel('Search the docs').fill('')
  await page.screenshot({ path: '../tmp/lab-verification/docs-desktop.png', fullPage: true })
  await page.getByRole('link', { name: 'Try in the lab: inspect the current agent →' }).click()
  // Documentation task links enter the selected lab sandbox; navigation runs nothing.
  await page.getByRole('heading', { name: 'Choose a persona', exact: true }).waitFor()
  await page.getByRole('button', { name: /Big Buck Owner/ }).click()
  await page.getByRole('button', { name: 'Run tool →' }).waitFor()
  await selectedOperation('gql_whoami')
  assert.equal(await page.locator('#operation').inputValue(), 'gql_whoami')
  assert.equal(await page.locator('.result-panel').count(), 0)
  console.log('PASS docs search/copy and safe preselection')
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto(`${base}/docs/agents`)
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth))
  await page.screenshot({ path: '../tmp/lab-verification/docs-mobile.png', fullPage: true })
  await page.goto(`${base}/session`)
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth))
  await page.screenshot({ path: '../tmp/lab-verification/lab-mobile.png', fullPage: true })
  assert.deepEqual(errors, [])
  console.log('PASS responsive layouts and no browser exceptions')
} catch (error) {
  console.error('Failure page:', page.url(), await page.locator('body').innerText())
  await page.screenshot({ path: '../tmp/lab-verification/failure.png', fullPage: true })
  throw error
} finally {
  await browser.close()
}
