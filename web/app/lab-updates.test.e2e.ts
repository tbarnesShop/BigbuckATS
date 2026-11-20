import * as assert from 'remix/assert'
import { createTestServer } from 'remix/node-fetch-server/test'
import { describe, it } from 'remix/test'
import { labFixture } from '../test/lab-fixture.tsx'

describe('lab asynchronous updates and expiry', () => {
  it('ignores a pre-execution poll after completion and preserves focused raw edits during newer polling', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    await page.clock.install()
    let release: () => void = () => {}
    let polls = 0
    await page.route('**/lab/status', async (route) => {
      polls++
      const first = polls === 1
      if (first)
        await new Promise<void>((resolve) => {
          release = resolve
        })
      await route.fulfill({
        json: {
          story: { title: first ? 'Obsolete poll' : 'Fresh poll', intro: 'Fixture context.', steps: [] },
          completed: [],
          sandbox: { generation: 1 },
        },
      })
    })
    await page.route('**/lab/execute', (route) =>
      route.fulfill({
        json: {
          ok: true,
          status: 200,
          output: { sample: true },
          duration: 1,
          links: [],
          story: { title: 'Completed request context', intro: 'Current context.', steps: [] },
          completed: [],
        },
      }),
    )
    await page.goto('/lab?operation=listPeople')
    await page.locator('#operation').waitFor()
    await page.getByText('About this experiment', { exact: true }).click()
    const firstPoll = page.waitForRequest('**/lab/status')
    await page.clock.fastForward(5000)
    await firstPoll
    await page.getByRole('button', { name: 'Send request →', exact: true }).click()
    await page.getByText('Completed request context', { exact: true }).waitFor()
    release()
    await page.waitForResponse('**/lab/status')
    assert.equal(await page.getByText('Obsolete poll', { exact: true }).count(), 0)
    const input = page.getByRole('textbox', { name: 'limit integer' })
    await input.fill('7')
    const before = await page.evaluate(() => scrollY)
    const response = page.waitForResponse('**/lab/status')
    await page.clock.fastForward(5000)
    await response
    await page.getByText('Fresh poll', { exact: true }).waitFor()
    assert.equal(await input.inputValue(), '7')
    assert.equal(await page.evaluate(() => document.activeElement?.tagName), 'INPUT')
    assert.equal(await page.evaluate(() => scrollY), before)
    assert.equal(await page.locator('#operation').inputValue(), 'listPeople')
  })

  it('ignores superseded record inspection without moving the editor or result', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    await page.clock.install()
    let release: () => void = () => {}
    await page.route('**/lab/execute', (route) =>
      route.fulfill({
        json: {
          ok: true,
          status: 200,
          duration: 1,
          output: { sample: true },
          links: [
            { kind: 'people', id: 'a', label: 'Sample A', href: '/people/a' },
            { kind: 'people', id: 'b', label: 'Sample B', href: '/people/b' },
          ],
        },
      }),
    )
    await page.route('**/lab/inspect?*', async (route) => {
      const id = new URL(route.request().url()).searchParams.get('id')
      if (id === 'a')
        await new Promise<void>((resolve) => {
          release = resolve
        })
      await route.fulfill({ json: { id, display_name: `Record ${id}` } })
    })
    await page.goto('/lab?operation=listPeople')
    await page.getByRole('button', { name: 'Send request →', exact: true }).click()
    // Related records opens on its own once a run returns records, with a JSON link per record.
    await page.getByRole('link', { name: 'Open Sample B as JSON' }).waitFor()
    await page.getByRole('button', { name: 'Sample B people' }).click()
    await page.getByText('Raw record', { exact: true }).click()
    await page
      .getByRole('region', { name: 'Inspected record' })
      .getByText(/Record b/)
      .waitFor()
    release()
    await page.waitForResponse(
      (response) =>
        response.url().includes('/lab/inspect?') && new URL(response.url()).searchParams.get('id') === 'a',
    )
    assert.match(await page.getByRole('region', { name: 'Inspected record' }).innerText(), /Record b/)
    assert.equal(await page.locator('#operation').inputValue(), 'listPeople')
    await page.getByText('Response from listPeople', { exact: true }).waitFor()
  })

  it('expires during execution, rejects its late result and preserves exact input for copying', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    const now = new Date('2098-11-05T18:00:00Z')
    await page.clock.install({ time: now })
    let release: () => void = () => {}
    await page.route('**/lab/execute', async (route) => {
      await new Promise<void>((resolve) => {
        release = resolve
      })
      await route.fulfill({
        json: { ok: true, status: 201, duration: 1, output: { id: 'obsolete' }, links: [] },
      })
    })
    await page.goto(
      `/lab?operation=createPerson&resetsAt=${encodeURIComponent(new Date(now.getTime() + 10000).toISOString())}`,
    )
    await page.waitForFunction(() => document.querySelectorAll('.execution-panel textarea').length === 1)
    const body = page.getByRole('textbox', { name: 'body * object', exact: true })
    const raw = ' {\n "person": {"display_name": "Sample"}\n } '
    await body.fill(raw)
    await page.getByRole('button', { name: 'Send request →', exact: true }).click()
    await page.getByText('Running createPerson…', { exact: true }).waitFor()
    await page.clock.fastForward(15000)
    await page.getByText('Workspace expired · execution blocked', { exact: true }).waitFor()
    release()
    await page.waitForResponse('**/lab/execute')
    assert.equal(await body.inputValue(), raw)
    assert.equal(await page.locator('.result-panel').count(), 0)
    assert.equal(await page.getByRole('button', { name: 'Send request →', exact: true }).isDisabled(), true)
    await page.getByRole('link', { name: 'Choose a persona and start again →' }).waitFor()
  })
  it('invalidates a reset generation without losing copyable input or reviving late inspection/history', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    await page.clock.install()
    await page.addInitScript(() =>
      Object.defineProperty(navigator, 'clipboard', {
        value: {
          async writeText(text: string) {
            document.documentElement.dataset.copied = text
          },
        },
      }),
    )
    let release: () => void = () => {}
    await page.route('**/lab/inspect?*', async (route) => {
      await new Promise<void>((resolve) => {
        release = resolve
      })
      await route.fulfill({ json: { id: 'old-record', display_name: 'Obsolete generation' } })
    })
    await page.route('**/lab/execute', (route) =>
      route.fulfill({
        json: {
          ok: true,
          status: 200,
          duration: 1,
          output: { id: 'old-record' },
          completed: ['create'],
          links: [{ kind: 'people', id: 'old-record', label: 'Old person', href: '/people/old-record' }],
        },
      }),
    )
    await page.route('**/lab/status', (route) =>
      route.fulfill({ status: 409, json: { code: 'sandbox_expired', error: 'Workspace reset.' } }),
    )
    await page.goto('/lab?operation=createPerson')
    const body = page.getByRole('textbox', { name: 'body * object', exact: true })
    const raw = ' {\n "person": {"display_name": "Sample"}\n } '
    await body.fill(raw)
    const inspectionStarted = page.waitForRequest('**/lab/inspect?*')
    await page.getByRole('button', { name: 'Send request →', exact: true }).click()
    await inspectionStarted
    await page.getByText('Draft recovery', { exact: true }).click()
    await page.getByRole('checkbox', { name: 'Remember disposable sample inputs in this tab' }).check()
    await page.locator('#operation').selectOption('listPeople')
    await page.locator('#operation').selectOption('createPerson')
    const reset = page.waitForResponse('**/lab/status')
    await page.clock.fastForward(5000)
    await reset
    await page.getByText('Workspace expired · execution blocked', { exact: true }).waitFor()
    assert.equal(await body.inputValue(), raw)
    assert.equal(await page.locator('.result-panel, .step-index.done').count(), 0)
    assert.equal(
      await page.evaluate(
        () => Object.keys(sessionStorage).filter((key) => key.startsWith('bigbuck:lab-draft:')).length,
      ),
      0,
    )
    release()
    await page.waitForResponse('**/lab/inspect?*')
    assert.equal(await page.getByText('Obsolete generation', { exact: true }).count(), 0)
    await page.goBack()
    assert.equal(await page.locator('#operation').inputValue(), 'createPerson')
    assert.equal(await body.inputValue(), raw)
    await page.getByRole('button', { name: 'Copy input', exact: true }).click()
    const copied = JSON.parse(await page.evaluate(() => document.documentElement.dataset.copied ?? '{}'))
    assert.equal(copied.fields.body, raw)
    await page.getByRole('link', { name: 'Choose a persona and start again →' }).click()
    await page.getByRole('dialog').getByRole('button', { name: 'Stay here' }).click()
    assert.equal(await body.inputValue(), raw)
  })
})
