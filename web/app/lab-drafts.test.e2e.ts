import * as assert from 'remix/assert'
import { createTestServer } from 'remix/node-fetch-server/test'
import { describe, it } from 'remix/test'
import { labFixture } from '../test/lab-fixture.tsx'
describe('lab draft navigation', () => {
  it('preserves malformed input on operation, story, history and document recovery without executing', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    let executions = 0
    page.on('request', (request) => {
      if (request.url().endsWith('/lab/execute')) executions++
    })
    await page.goto('/lab')
    await page.getByText('Draft recovery', { exact: true }).click()
    await page.getByRole('checkbox', { name: 'Remember disposable sample inputs in this tab' }).check()
    const raw = ' {\n "person": BROKEN,\n\n '
    await page.getByRole('textbox', { name: 'body * object', exact: true }).fill(raw)
    await page.locator('#operation').selectOption('listPeople')
    await page.getByRole('textbox', { name: 'limit integer' }).fill('7')
    await page.goBack()
    assert.equal(await page.getByRole('textbox', { name: 'body * object', exact: true }).inputValue(), raw)
    await page.goForward()
    assert.equal(await page.getByRole('textbox', { name: 'limit integer' }).inputValue(), '7')
    await page.getByRole('button', { name: /Create a sample person/ }).click()
    assert.equal(await page.getByRole('textbox', { name: 'body * object', exact: true }).inputValue(), raw)
    await page.getByRole('button', { name: 'Send request →', exact: true }).click()
    await page
      .getByRole('alert')
      .getByText(/Invalid JSON/)
      .waitFor()
    assert.equal(executions, 0)
    // listPeople is memory-only, so leaving offers recovery for all unfinished work.
    await page.getByRole('link', { name: 'Docs', exact: true }).click()
    await page.getByRole('dialog').getByRole('button', { name: 'Discard and continue' }).click()
    await page.waitForURL('**/docs')
    await page.goBack()
    assert.equal(await page.getByRole('textbox', { name: 'body * object', exact: true }).inputValue(), raw)
    await page.reload()
    assert.equal(await page.getByRole('textbox', { name: 'body * object', exact: true }).inputValue(), raw)
    await page.getByRole('button', { name: 'Load step inputs' }).click()
    assert.match(
      await page.getByRole('textbox', { name: 'body * object', exact: true }).inputValue(),
      /Sample person/,
    )
    assert.equal(executions, 0)
  })
  it('guards unfinished input before posting an interface switch without running a request', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    let executions = 0
    page.on('request', (request) => {
      if (new URL(request.url()).pathname === '/lab/execute') executions++
    })
    await page.goto('/lab?operation=createPerson')
    const body = page.getByRole('textbox', { name: 'body * object', exact: true })
    await body.fill('{ BROKEN')
    await page
      .getByRole('navigation', { name: 'Switch interface' })
      .getByRole('button', { name: 'MCP', exact: true })
      .click()
    const dialog = page.getByRole('dialog')
    await dialog.getByRole('button', { name: 'Stay here' }).click()
    assert.equal(await body.inputValue(), '{ BROKEN')
    await page.route('**/lab', (route) =>
      route.fulfill({ contentType: 'text/html', body: 'Interface switched' }),
    )
    await page
      .getByRole('navigation', { name: 'Switch interface' })
      .getByRole('button', { name: 'MCP', exact: true })
      .click()
    const posted = page.waitForRequest(
      (request) => request.method() === 'POST' && new URL(request.url()).pathname === '/lab',
    )
    await dialog.getByRole('button', { name: 'Discard and continue' }).click()
    const form = new URLSearchParams((await posted).postData() ?? '')
    assert.equal(form.get('intent'), 'switch-interface')
    assert.equal(form.get('surface'), 'mcp')
    assert.equal(form.has('email'), false)
    assert.equal(executions, 0)
  })
  it('storage denial and synthetic credential input offer copy/discard recovery', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    await page.addInitScript(() => {
      Object.defineProperty(window, 'sessionStorage', {
        get() {
          throw new Error('SecurityError')
        },
      })
      Object.defineProperty(navigator, 'clipboard', {
        value: {
          async writeText(text: string) {
            document.documentElement.dataset.copy = text
          },
        },
      })
    })
    await page.goto('/lab')
    await page.getByText('Draft recovery', { exact: true }).click()
    await page.getByRole('checkbox', { name: 'Remember disposable sample inputs in this tab' }).check()
    await page
      .getByRole('textbox', { name: 'body * object', exact: true })
      .fill('{"token":"synthetic-test-value", BROKEN')
    await page.getByRole('link', { name: 'Docs', exact: true }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByRole('button', { name: 'Copy unfinished inputs' }).click()
    await dialog.getByRole('status').getByText('Unfinished inputs copied.').waitFor()
    assert.match(
      await page.evaluate(() => document.documentElement.dataset.copy ?? ''),
      /synthetic-test-value/,
    )
    await dialog.getByRole('button', { name: 'Stay here' }).click()
    assert.equal(await dialog.isVisible(), false)
    assert.match(
      await page.getByRole('textbox', { name: 'body * object', exact: true }).inputValue(),
      /synthetic-test-value/,
    )
  })
  it('restores only the authorized persona and generation, with no request from navigation', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    let executions = 0
    page.on('request', (request) => {
      if (request.url().endsWith('/lab/execute')) executions++
    })
    await page.goto('/lab?operation=createPerson')
    await page.getByText('Draft recovery', { exact: true }).click()
    await page.getByRole('checkbox', { name: 'Remember disposable sample inputs in this tab' }).check()
    const raw = ' {"person": BROKEN '
    await page.getByRole('textbox', { name: 'body * object', exact: true }).fill(raw)
    await page.goto('/lab?operation=createPerson&persona=other')
    assert.notEqual(await page.getByRole('textbox', { name: 'body * object', exact: true }).inputValue(), raw)
    await page.goto('/lab?operation=createPerson&generation=2')
    assert.notEqual(await page.getByRole('textbox', { name: 'body * object', exact: true }).inputValue(), raw)
    await page.goto('/lab?operation=createPerson')
    assert.equal(await page.getByRole('textbox', { name: 'body * object', exact: true }).inputValue(), raw)
    assert.equal(executions, 0)
  })
})
