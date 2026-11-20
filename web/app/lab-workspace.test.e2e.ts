import * as assert from 'remix/assert'
import { createTestServer } from 'remix/node-fetch-server/test'
import { describe, it } from 'remix/test'
import { labFixture } from '../test/lab-fixture.tsx'
describe('compact lab workspace', () => {
  it('keeps a common request actionable before desktop scrolling and collapses experiments on mobile', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    for (const [width, height] of [
      [1280, 800],
      [1440, 900],
    ]) {
      await page.setViewportSize({ width, height })
      await page.goto('/lab?operation=layoutFixture')
      const body = page.getByRole('textbox', { name: 'body * object', exact: true })
      await body.fill(
        '{\n "a": 1,\n "b": 2,\n "c": 3,\n "d": 4,\n "e": 5,\n "f": 6,\n "g": 7,\n "h": 8,\n "i": 9,\n "j": 10\n}',
      )
      const run = await page.getByRole('button', { name: 'Send request →', exact: true }).boundingBox()
      const editor = await body.boundingBox()
      assert.equal(!!run && run.y + run.height <= height, true)
      assert.equal(!!editor && editor.y >= 0, true)
      assert.equal(await page.evaluate(() => scrollY), 0)
      // These disposable fixture edits need no recovery across the controlled reload below.
      await page.getByText('Draft recovery', { exact: true }).click()
      await page.getByRole('checkbox', { name: 'Remember disposable sample inputs in this tab' }).check()
    }
    for (const width of [900, 390, 320]) {
      await page.setViewportSize({ width, height: 844 })
      await page.goto('/lab?operation=layoutFixture')
      assert.equal(await page.locator('.story-guide').getAttribute('open'), null)
      const editor = await page.getByRole('textbox', { name: 'id string', exact: true }).boundingBox()
      assert.equal(!!editor && editor.y + editor.height <= 844, true)
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true)
      await page.getByText('Suggested experiments', { exact: true }).click()
      await page.getByRole('button', { name: /Create a sample person/ }).waitFor()
      await page.getByText('Suggested experiments', { exact: true }).click()
    }
  })
  it('locks execution choices, preserves submit focus and scroll, labels output, and moves only on View response', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    await page.setViewportSize({ width: 1280, height: 800 })
    let finish: () => void = () => {}
    await page.route('**/lab/execute', async (route) => {
      await new Promise<void>((resolve) => {
        finish = resolve
      })
      await route.fulfill({
        json: { ok: true, status: 200, duration: 10, output: { fixture: 'sample' }, links: [] },
      })
    })
    await page.goto('/lab?operation=listPeople')
    await page.getByRole('textbox', { name: 'limit integer' }).fill('2')
    const before = await page.evaluate(() => scrollY)
    await page.getByRole('button', { name: 'Send request →', exact: true }).click()
    await page.getByRole('status').getByText('Running listPeople…').waitFor()
    assert.equal(await page.locator('#operation').isDisabled(), true)
    assert.equal(
      await page.getByRole('button', { name: 'Running…', exact: true }).getAttribute('aria-disabled'),
      'true',
    )
    finish()
    await page.getByRole('status').getByText('Completed · 200').waitFor()
    assert.equal(await page.evaluate(() => document.activeElement?.textContent), 'Send request →')
    assert.equal(await page.evaluate(() => scrollY), before)
    await page.getByRole('link', { name: 'View response ↓' }).click()
    await page.getByRole('status').getByText('Completed · 200').waitFor()
    await page.goBack()
    await page.getByRole('status').getByText('Completed · 200').waitFor()
    await page.locator('#operation').selectOption('createPerson')
    await page.getByText('Response from listPeople', { exact: true }).waitFor()
    await page.getByRole('link', { name: 'View response ↓' }).click()
    assert.equal(new URL(page.url()).hash, '#lab-response')
    assert.equal(
      await page.evaluate(
        () =>
          document.querySelector('#lab-response')!.getBoundingClientRect().top >=
          document.querySelector('.demo-workspace-banner')!.getBoundingClientRect().bottom,
      ),
      true,
    )
  })
  it('distinguishes empty success from connection loss without retrying or losing inputs', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    let calls = 0
    await page.route('**/lab/execute', async (route) => {
      calls++
      if (calls === 1)
        await route.fulfill({ json: { ok: true, status: 204, duration: 1, output: null, links: [] } })
      else await route.abort('failed')
    })
    await page.goto('/lab?operation=listPeople')
    const input = page.getByRole('textbox', { name: 'limit integer' })
    await input.fill('2')
    await input.press('Enter')
    await page.getByRole('status').getByText('Completed · empty response').waitFor()
    await page.waitForFunction(() => document.activeElement?.tagName === 'INPUT')
    await page.getByRole('button', { name: 'Send request →', exact: true }).click()
    await page.getByRole('status').getByText('Request outcome unknown').waitFor()
    await page
      .getByRole('alert')
      .getByText(/check the record before retrying/)
      .waitFor()
    assert.equal(await input.inputValue(), '2')
    assert.equal(calls, 2)
    await page.unroute('**/lab/execute')
    await page.route('**/lab/execute', (route) =>
      route.fulfill({
        json: {
          ok: false,
          status: 503,
          outcome: 'unknown',
          duration: 0,
          output: { code: 'request_outcome_unknown' },
          error: 'The upstream connection ended. Check the record before retrying.',
          links: [],
        },
      }),
    )
    await page.getByRole('button', { name: 'Send request →', exact: true }).click()
    await page.getByRole('status').getByText('Request outcome unknown').waitFor()
    await page.getByText('503 Outcome unknown', { exact: true }).waitFor()
    assert.equal(await input.inputValue(), '2')
  })
  it('keeps a 100-line draft and 200-line response reachable through validation, narrow reflow and doubled text', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    await page.setViewportSize({ width: 1280, height: 800 })
    await page.goto('/lab?operation=layoutFixture')
    const raw = JSON.stringify(
      { notes: Array.from({ length: 96 }, (_, index) => `Sample line ${index + 1}`) },
      null,
      2,
    )
    assert.equal(raw.split('\n').length, 100)
    const body = page.getByRole('textbox', { name: 'body * object', exact: true })
    const run = page.getByRole('button', { name: 'Send request →', exact: true })
    await body.fill(raw.slice(0, -1))
    await run.click()
    await page
      .getByRole('alert')
      .getByText(/Invalid JSON/)
      .waitFor()
    assert.equal(await body.inputValue(), raw.slice(0, -1))
    await body.fill(raw)
    await run.scrollIntoViewIfNeeded()
    await run.focus()
    const scroll = await page.evaluate(() => scrollY)
    await run.click()
    const output = page.getByRole('region', { name: 'Response content', exact: true })
    await output.waitFor()
    assert.equal(await body.inputValue(), raw)
    assert.equal(await page.evaluate(() => scrollY), scroll)
    assert.equal(JSON.parse(await output.innerText()).lines.length, 200)
    await page.getByRole('link', { name: 'View response ↓', exact: true }).click()
    assert.equal(await output.evaluate((node) => node.scrollHeight > node.clientHeight), true)
    await output.focus()
    await page.keyboard.press('End')
    await page.waitForFunction(() => {
      const region = document.querySelector<HTMLElement>('[aria-label="Response content"]')
      return !!region && region.scrollTop + region.clientHeight >= region.scrollHeight - 2
    })
    assert.equal(
      await output.evaluate((node) => node.scrollTop + node.clientHeight >= node.scrollHeight - 2),
      true,
    )
    for (const width of [390, 320]) {
      await page.setViewportSize({ width, height: 844 })
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true)
      assert.equal(await body.inputValue(), raw)
      assert.match(await output.innerText(), /Sample output 200/)
    }
    await page.setViewportSize({ width: 1280, height: 800 })
    // Synthetic text enlargement complements 320px reflow; native mobile zoom is a manual gate.
    await page.evaluate(() => {
      const elements = Array.from(document.querySelectorAll<HTMLElement>('.lab-root, .lab-root *'))
      const sizes = elements.map((node) => ({
        font: parseFloat(getComputedStyle(node).fontSize),
        line: parseFloat(getComputedStyle(node).lineHeight),
      }))
      elements.forEach((node, index) => {
        node.style.fontSize = `${sizes[index].font * 2}px`
        if (Number.isFinite(sizes[index].line)) node.style.lineHeight = `${sizes[index].line * 2}px`
      })
    })
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true)
    assert.equal(await body.inputValue(), raw)
    await run.scrollIntoViewIfNeeded()
    assert.equal(await run.isVisible(), true)
    assert.match(await output.innerText(), /Sample output 200/)
  })
})
