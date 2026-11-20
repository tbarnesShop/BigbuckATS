import { chromium } from 'playwright'
import assert from 'node:assert/strict'
import { mkdir, writeFile } from 'node:fs/promises'
import { setTimeout as pause } from 'node:timers/promises'

// Real read-only acceptance against the registered disposable demo workspaces.
// Normal role-bound demo sign-in creates credentials; no domain writes or resets run here.
const base = process.env.LAB_URL ?? 'http://127.0.0.1:44100'
const directory = '../tmp/lab-verification/matrix'
const browser = await chromium.launch({ headless: true })
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } })
const page = await context.newPage()
page.setDefaultTimeout(20000)
const errors: string[] = []
page.on('pageerror', (error) => errors.push(error.message))
const observations: Array<Record<string, unknown>> = []
let executions = 0
await page.route('**/lab/execute', async (route) => {
  const input = route.request().postDataJSON()
  const readOnly =
    ['listPeople', 'listConfigPlans'].includes(input.name) ||
    ['bigbuck person list', 'bigbuck config plans'].includes(input.command)
  if (!readOnly) {
    await route.fulfill({
      status: 400,
      json: {
        ok: false,
        output: {
          code: 'verification_read_only',
          title: 'The verification harness blocked an unexpected operation.',
        },
      },
    })
    return
  }
  await route.continue()
})
page.on('request', (request) => {
  if (new URL(request.url()).pathname === '/lab/execute' && request.method() === 'POST') executions++
})
async function sampleRecovery() {
  const recovery = page.getByRole('checkbox', { name: 'Remember disposable sample inputs in this tab' })
  if (!(await recovery.isVisible())) await page.getByText('Draft recovery', { exact: true }).click()
  await recovery.check()
}
async function run() {
  const response = page.waitForResponse((response) => new URL(response.url()).pathname === '/lab/execute')
  const button = page.getByRole('button', { name: /^(Send request|Run tool|Run command) →$/ })
  await button.click()
  const result = await (await response).json()
  await button.waitFor()
  await page.waitForFunction(
    () => !document.querySelector<HTMLButtonElement>('.execution-panel button[type=submit]')?.disabled,
  )
  return result
}
async function choose(surface: string, name: string) {
  await page.waitForFunction(() => {
    const button = document.querySelector<HTMLButtonElement>('.execution-panel button[type=submit]')
    return !!button && !button.disabled && button.getAttribute('aria-disabled') !== 'true'
  })
  if (surface === 'cli') await page.getByLabel('Command', { exact: true }).fill(name)
  else await page.locator('#operation').selectOption(name)
}
try {
  await mkdir(directory, { recursive: true })
  for (const [persona, role] of [
    ['Big Buck Owner', 'owner'],
    ['Ada Admin', 'admin'],
    ['Riley Recruiter', 'recruiter'],
    ['Harper Manager', 'hiring_manager'],
  ]) {
    for (const mode of ['explore', 'compare', 'connect']) {
      const caseStarted = Date.now()
      await page.goto(`${base}/session?surface=api&mode=${mode}`)
      await page.getByRole('button', { name: new RegExp(persona) }).click()
      await page.getByRole('heading', { name: 'API lab', exact: true }).waitFor()
      for (const surface of ['api', 'mcp', 'cli']) {
        if (surface !== 'api') {
          await sampleRecovery()
          const before = executions
          await page
            .getByRole('navigation', { name: 'Switch interface' })
            .getByRole('button', { name: surface.toUpperCase(), exact: true })
            .click()
          await page.getByRole('heading', { name: `${surface.toUpperCase()} lab`, exact: true }).waitFor()
          assert.equal(executions, before, 'Switching interfaces ran a domain request')
        }
        assert.match(
          await page.getByRole('region', { name: 'Demo workspace' }).innerText(),
          new RegExp(persona),
        )
        assert.equal(await page.getByRole('heading', { name: 'Choose a persona', exact: true }).count(), 0)
        await choose(surface, surface === 'cli' ? 'bigbuck person list' : 'listPeople')
        const read = await run()
        assert.equal(read.ok, true, JSON.stringify(read.output))
        const rows = Array.isArray(read.output) ? read.output : read.output.data
        assert.ok(Array.isArray(rows), `${surface} did not return a person list`)
        if (role === 'recruiter' || role === 'hiring_manager')
          assert.ok(
            rows.every((person: { visibility: string }) => person.visibility === 'public'),
            'Restricted people crossed the role boundary',
          )
        // This endpoint is read-only and permitted only for Owner/Admin among these personas.
        await choose(surface, surface === 'cli' ? 'bigbuck config plans' : 'listConfigPlans')
        const permission = await run()
        const allowed = role === 'owner' || role === 'admin'
        assert.equal(permission.ok, allowed, JSON.stringify(permission.output))
        if (!allowed) {
          assert.equal(permission.outcome, undefined, 'A permission refusal was reported as an unknown write')
          assert.equal(permission.status, surface === 'cli' ? 422 : 403)
          assert.match(JSON.stringify(permission.output), /forbidden|config\.plan/)
          await page.getByText(`Failed · ${permission.status}`, { exact: true }).waitFor()
          await choose(surface, surface === 'cli' ? 'bigbuck person list' : 'listPeople')
          assert.equal((await run()).ok, true, 'The user could not continue after a known refusal')
        }
        observations.push({
          persona,
          role,
          mode,
          surface,
          read: 'passed',
          permission: allowed ? 'allowed' : 'refused and recovered',
          visiblePeople: rows.length,
        })
        await sampleRecovery()
      }
      await page.goto(`${base}/session?surface=ui&mode=${mode}`)
      await page.getByRole('button', { name: new RegExp(persona) }).click()
      await page.waitForURL('**/today')
      await page.getByRole('heading', { name: 'Today', exact: true }).waitFor()
      assert.match(
        await page.getByRole('region', { name: 'Demo workspace' }).innerText(),
        new RegExp(persona),
      )
      assert.equal(await page.getByRole('heading', { name: 'UI lab', exact: true }).count(), 0)
      await page.getByRole('link', { name: 'Back to lab', exact: true }).click()
      await page.waitForURL('**/session')
      assert.equal(await page.locator('.lab-card').count(), 4)
      observations.push({ persona, role, mode, surface: 'ui', handoff: 'Today and public lab return passed' })
      console.log(
        `PASS ${persona} · ${mode}: API/MCP/CLI reads, permission boundary, persona continuity and direct UI handoff`,
      )
      await writeFile(
        `${directory}/results.json`,
        JSON.stringify({ observations, executions, errors }, null, 2),
      )
      // Story reads fan out. Pace cases below the existing API rate limit.
      await pause(Math.max(0, 25000 - (Date.now() - caseStarted)))
    }
  }
  assert.deepEqual(errors, [])
  assert.equal(observations.length, 48)
  console.log('PASS all 48 persona/interface/mode combinations; no browser exceptions')
} catch (error) {
  console.error('Failure page:', page.url(), await page.locator('body').innerText())
  await page.screenshot({ path: `${directory}/failure.png`, fullPage: true })
  throw error
} finally {
  await writeFile(`${directory}/results.json`, JSON.stringify({ observations, executions, errors }, null, 2))
  await browser.close()
}
