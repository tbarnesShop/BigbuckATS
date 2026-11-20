import * as assert from 'remix/assert'
import { createTestServer } from 'remix/node-fetch-server/test'
import { describe, it } from 'remix/test'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

import { router } from './router.ts'
import { repoRoot, cliHelp } from './data/lab/catalog.ts'

describe('documentation reading and navigation', () => {
  it('mobile Topics overlays the article, filters references, and dismisses predictably', async (t) => {
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto('/docs/data-model')
    const title = page.getByRole('heading', {
      name: 'One person, many recruiting relationships',
      exact: true,
    })
    const before = await title.boundingBox()
    const topics = page.getByRole('button', { name: /^Topics/ })
    await topics.click()
    const nav = page.getByRole('navigation', { name: 'Documentation', exact: true })
    assert.equal(
      await nav.getByRole('link', { name: 'Data model', exact: true }).getAttribute('aria-current'),
      'page',
    )
    assert.equal((await title.boundingBox())?.y, before?.y)
    await nav.getByRole('link', { name: 'Start here', exact: true }).press('Escape')
    await nav.waitFor({ state: 'hidden' })
    assert.equal(await page.evaluate(() => document.activeElement?.tagName), 'SUMMARY')
    const search = page.getByRole('searchbox', { name: 'Search the docs', exact: true })
    await search.fill('graphql')
    await nav.getByRole('link', { name: 'GraphQL', exact: true }).waitFor()
    await search.fill('no-such-documentation-zzzz')
    await nav.getByText('No matching documentation. Try another term.').waitFor()
    assert.equal(await nav.getByRole('link').count(), 0)
    await search.press('Escape')
    await nav.waitFor({ state: 'hidden' })
    assert.equal(await search.inputValue(), 'no-such-documentation-zzzz')
    await search.fill('REST')
    await nav.getByRole('link', { name: 'REST / OpenAPI', exact: true }).waitFor()
    await page.locator('.docs-header').click({ position: { x: 8, y: 8 } })
    await nav.waitFor({ state: 'hidden' })
  })

  it('a tapped search result navigates on iOS, and Enter opens the top match', async (t) => {
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto('/docs/start')
    const search = page.getByRole('searchbox', { name: 'Search the docs', exact: true })
    const nav = page.getByRole('navigation', { name: 'Documentation', exact: true })
    await search.fill('graphql')
    const result = nav.getByRole('link', { name: 'GraphQL', exact: true })
    await result.waitFor()
    // iOS Safari never focuses a tapped link: the search box blurs with no relatedTarget before the click.
    await search.evaluate((input) => (input as HTMLInputElement).blur())
    await result.waitFor()
    await result.click()
    await page.waitForURL('**/docs/reference/graphql')

    await page.goto('/docs/start')
    await search.fill('permissions')
    await search.press('Enter')
    await page.waitForURL('**/docs/permissions')
  })

  it('code copying announces success and failure while retaining focus and source text', async (t) => {
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await page.addInitScript(() => {
      Object.defineProperty(navigator, 'clipboard', {
        configurable: true,
        value: {
          async writeText(text: string) {
            if (document.documentElement.dataset.copyFailure) throw new Error('Clipboard unavailable')
            document.documentElement.dataset.copied = text
          },
        },
      })
    })
    await page.goto('/docs/data-model')
    const region = page.getByRole('region', { name: 'json code example', exact: true }).first()
    const source = await region.textContent()
    await page.getByRole('button', { name: 'Copy', exact: true }).first().click()
    await page.getByRole('status').getByText('Code copied to clipboard.').waitFor()
    assert.equal(await page.evaluate(() => document.documentElement.dataset.copied), source)
    assert.equal(await page.evaluate(() => document.activeElement?.textContent), 'Copied')
    await page.evaluate(() => {
      document.documentElement.dataset.copyFailure = 'true'
    })
    await page.getByRole('button', { name: 'Copied', exact: true }).click()
    await page
      .getByRole('status')
      .getByText('Could not copy. Select the code and copy it manually.')
      .waitFor()
    assert.equal(await region.textContent(), source)
    assert.equal(await page.evaluate(() => document.activeElement?.textContent), 'Copy failed')
    await region.focus()
    assert.equal(await page.evaluate(() => document.activeElement?.tagName), 'PRE')
  })

  it('direct anchors, outline links and browser history keep targets clear of the sticky header', async (t) => {
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await page.setViewportSize({ width: 1440, height: 1000 })
    await page.goto('/docs/interop#graphql')
    await page.waitForFunction(() => {
      const target = document.querySelector('#graphql')!.getBoundingClientRect()
      return target.top >= document.querySelector('.docs-header')!.getBoundingClientRect().bottom
    })
    const outline = page.getByRole('complementary', { name: 'Article outline', exact: true })
    await outline.getByRole('link', { name: 'CLI and SDK', exact: true }).click()
    await page.waitForURL((url) => url.hash === '#cli-and-sdk')
    assert.equal(
      await page.evaluate(
        () =>
          document.querySelector('#cli-and-sdk')!.getBoundingClientRect().top >=
          document.querySelector('.docs-header')!.getBoundingClientRect().bottom,
      ),
      true,
    )
    await page.goBack()
    await page.waitForURL((url) => url.hash === '#graphql')
    await page.waitForFunction(() => {
      const target = document.querySelector('#graphql')!.getBoundingClientRect()
      return (
        target.top >= document.querySelector('.docs-header')!.getBoundingClientRect().bottom &&
        target.bottom < innerHeight
      )
    })
    await page.goForward()
    await page.waitForURL((url) => url.hash === '#cli-and-sdk')
    await page.keyboard.press('/')
    assert.equal(await page.evaluate(() => document.activeElement?.id), 'docs-search')
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto('/docs/data-model')
    await page.goto('/docs/interop#graphql')
    await page.waitForFunction(
      () =>
        document.querySelector('#graphql')!.getBoundingClientRect().top >=
        document.querySelector('.docs-header')!.getBoundingClientRect().bottom,
    )
    await page.getByRole('heading', { name: 'Retries and stale state', exact: true }).scrollIntoViewIfNeeded()
    await page.getByRole('heading', { name: 'Retries and stale state', exact: true }).click()
    await page.keyboard.press('/')
    assert.equal(
      await page.evaluate(() => {
        const input = document.querySelector('#docs-search')!.getBoundingClientRect()
        return (
          document.activeElement?.id === 'docs-search' &&
          input.top >= document.querySelector('.docs-header')!.getBoundingClientRect().bottom &&
          input.bottom <= innerHeight
        )
      }),
      true,
    )
  })

  it('all contract references retain their source and reflow into accessible code regions', async (t) => {
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    for (const [kind, title] of [
      ['rest', 'REST reference'],
      ['graphql', 'GraphQL schema'],
      ['mcp', 'MCP reference'],
      ['cli', 'CLI reference'],
    ]) {
      await page.setViewportSize({ width: 1280, height: 900 })
      await page.goto(`/docs/reference/${kind}`)
      await page.getByRole('heading', { name: title, exact: true }).waitFor()
      const current = page
        .getByRole('navigation', { name: 'Documentation', exact: true })
        .locator('[aria-current="page"]')
      assert.equal(await current.getAttribute('href'), `/docs/reference/${kind}`)
      if (kind === 'graphql')
        assert.equal(
          (await page.locator('.docs-code code').textContent())?.trim(),
          readFileSync(resolve(repoRoot, 'schema.graphql'), 'utf8').trim(),
        )
      if (kind === 'cli')
        assert.equal((await page.locator('.docs-code code').textContent())?.trim(), cliHelp().trim())
      for (const width of [1201, 1200, 901, 900, 390, 320]) {
        await page.setViewportSize({ width, height: 900 })
        assert.equal(
          await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
          true,
          `${kind} at ${width}`,
        )
      }
      const code = page.getByRole('region', { name: /code example/ }).first()
      assert.equal(await code.getAttribute('tabindex'), '0')
    }
  })

  it('the article remains readable at doubled text and Topics works without JavaScript', async (t) => {
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await page.goto('/docs/interop')
    await page.evaluate(() => {
      const elements = Array.from(document.querySelectorAll<HTMLElement>('body, body *'))
      const sizes = elements.map((node) => getComputedStyle(node).fontSize)
      elements.forEach((node, index) => {
        node.style.fontSize = `${parseFloat(sizes[index]) * 2}px`
      })
    })
    for (const width of [1280, 390, 320]) {
      await page.setViewportSize({ width, height: 900 })
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true)
    }
    const context = await page
      .context()
      .browser()!
      .newContext({ javaScriptEnabled: false, viewport: { width: 320, height: 800 } })
    t.after(() => context.close())
    const fallback = await context.newPage()
    fallback.setDefaultTimeout(15_000)
    await fallback.goto(page.url())
    await fallback.getByRole('button', { name: /^Topics/ }).click()
    await fallback
      .getByRole('navigation', { name: 'Documentation', exact: true })
      .getByRole('link', { name: 'GraphQL', exact: true })
      .click()
    await fallback.getByRole('heading', { name: 'GraphQL schema', exact: true }).waitFor()
    assert.equal(await fallback.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true)
  })
})
