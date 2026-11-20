import { chromium } from 'playwright'
import assert from 'node:assert/strict'
import http from 'node:http'
import type { AddressInfo } from 'node:net'
import { mkdir, writeFile } from 'node:fs/promises'
import { createRequestListener } from 'remix/node-fetch-server'

// Import the fixture after selecting test mode so its asset server starts no development watchers.
process.env.NODE_ENV ??= 'test'
const { labFixture } = await import('../test/lab-fixture.tsx')

// Chromium touch/mobile emulation; does not claim native iOS Safari verification.
const server = http.createServer(createRequestListener(labFixture().fetch))
await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`
const directory = '../tmp/lab-verification/mobile'
const browser = await chromium.launch({ headless: true })
const observations: Array<Record<string, unknown>> = []
const errors: string[] = []
const raw = JSON.stringify(
  { notes: Array.from({ length: 96 }, (_, index) => `Sample line ${index + 1}`) },
  null,
  2,
)
try {
  await mkdir(directory, { recursive: true })
  for (const colorScheme of ['light', 'dark'] as const) {
    for (const width of [390, 320]) {
      const context = await browser.newContext({
        viewport: { width, height: 844 },
        isMobile: true,
        hasTouch: true,
        deviceScaleFactor: 3,
        colorScheme,
      })
      const page = await context.newPage()
      page.setDefaultTimeout(15000)
      page.on('pageerror', (error) => errors.push(error.message))
      for (const surface of ['api', 'mcp', 'cli']) {
        await page.goto(`${base}/lab?surface=${surface}&operation=layoutFixture`)
        await page.waitForFunction(() => {
          const button = document.querySelector<HTMLButtonElement>('.execution-panel button[type=submit]')
          return !!button && !button.disabled
        })
        const viewportMeta = await page.locator('meta[name=viewport]').getAttribute('content')
        assert.match(viewportMeta ?? '', /width=device-width/)
        assert.doesNotMatch(viewportMeta ?? '', /user-scalable\s*=\s*no|maximum-scale\s*=\s*1(?:[,. ]|$)/)
        const input =
          surface === 'cli'
            ? page.getByLabel('Command', { exact: true })
            : page.getByRole('textbox', { name: 'id string', exact: true })
        const first = await input.boundingBox()
        assert.ok(
          first && first.y + first.height <= 844,
          'The first field starts below the mobile task viewport',
        )
        const scaleBefore = await page.evaluate(() => visualViewport?.scale)
        await input.tap()
        const scaleAfter = await page.evaluate(() => visualViewport?.scale)
        assert.equal(scaleAfter, scaleBefore, 'Input focus changed emulated viewport zoom')
        const fonts = await page
          .locator(
            '.execution-panel input, .execution-panel textarea, .execution-panel select, .operation-selector input, .operation-selector select',
          )
          .evaluateAll((nodes) => nodes.map((node) => parseFloat(getComputedStyle(node).fontSize)))
        assert.ok(
          fonts.every((size) => size >= 16),
          'A mobile editable control uses text smaller than 16px',
        )
        if (surface === 'cli') await input.fill('bigbuck person list')
        else await page.getByRole('textbox', { name: 'body * object', exact: true }).fill(raw)
        await page.getByText('Draft recovery', { exact: true }).click()
        await page.getByRole('checkbox', { name: 'Remember disposable sample inputs in this tab' }).check()
        let calls = 0
        page.on('request', (request) => {
          if (new URL(request.url()).pathname === '/lab/execute') calls++
        })
        const run = page.getByRole('button', { name: /^(Send request|Run tool|Run command) →$/ })
        const target = await run.boundingBox()
        assert.ok(target && target.height >= 44, 'Run is smaller than the mobile touch target')
        const response = page.waitForResponse('**/lab/execute')
        await run.tap()
        await response
        await page.getByText('Completed · 200', { exact: true }).waitFor()
        assert.equal(calls, 1)
        await page.getByRole('link', { name: 'View response ↓', exact: true }).tap()
        const geometry = await page.evaluate(() => ({
          content: document.documentElement.scrollWidth,
          viewport: innerWidth,
          response: document.querySelector('.result-panel')!.getBoundingClientRect().top,
          banner: document.querySelector('.demo-workspace-banner')!.getBoundingClientRect().bottom,
        }))
        assert.ok(geometry.content <= geometry.viewport, 'Mobile document overflows horizontally')
        assert.ok(geometry.response >= geometry.banner, 'Response anchor is hidden behind the sticky banner')
        if (surface !== 'cli')
          assert.equal(
            await page.getByRole('textbox', { name: 'body * object', exact: true }).inputValue(),
            raw,
          )
        // A known refusal must retain input and permit an explicit successful retry.
        await page.route('**/lab/execute', (route) =>
          route.fulfill({
            json: {
              ok: false,
              status: 403,
              duration: 1,
              output: { code: 'forbidden', title: 'Sample permission refusal' },
              links: [],
            },
          }),
        )
        await run.tap()
        await page.getByText('Failed · 403', { exact: true }).waitFor()
        assert.equal(calls, 2)
        await page.unroute('**/lab/execute')
        await run.tap()
        await page.getByText('Completed · 200', { exact: true }).waitFor()
        assert.equal(calls, 3)
        observations.push({
          colorScheme,
          width,
          surface,
          firstField: 'visible',
          focusScale: scaleAfter,
          minimumInputFont: Math.min(...fonts),
          touchTarget: target.height,
          anchor: geometry,
          failureRecovery: 'passed',
        })
      }
      await context.close()
    }
  }
  assert.deepEqual(errors, [])
  console.log(
    'PASS 12 touch/mobile interface/theme/width cases: readable fields, focus scale, zoom-enabled viewport, touch targets, response anchors and known-failure recovery',
  )
} finally {
  await writeFile(
    `${directory}/results.json`,
    JSON.stringify(
      {
        engine: 'Chromium mobile emulation',
        nativeIOS: 'Deferred by user; automated checks accepted for this checkpoint',
        observations,
        errors,
      },
      null,
      2,
    ),
  )
  await browser.close()
  server.closeAllConnections()
  server.close()
}
