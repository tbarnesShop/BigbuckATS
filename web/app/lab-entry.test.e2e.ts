import * as assert from 'remix/assert'
import { createTestServer } from 'remix/node-fetch-server/test'
import { describe, it } from 'remix/test'
import { labFixture } from '../test/lab-fixture.tsx'
describe('compact lab entry and persona selection', () => {
  it('offers four public choices and opens persona selection directly, with no preview wall', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto('/session')
    assert.equal(await page.locator('.lab-card').count(), 4)
    await page.getByRole('link', { name: /API.*Try a request/ }).click()
    await page.getByRole('heading', { name: 'Choose a persona', exact: true }).waitFor()
    assert.equal(await page.locator('.lab-card').count(), 0)
    assert.equal(await page.locator('.lab-preview').count(), 0)
    const button = await page.getByRole('button', { name: /Fixture persona/ }).boundingBox()
    assert.equal(!!button && button.y + button.height <= 844, true)
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true)
  })
  it('keeps surface, operation, step and mode on persona submit', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    await page.goto('/session?surface=api&mode=connect&operation=createPerson&step=create')
    await page.getByText('Connect uses the shared tools sandbox across MCP, API and CLI.').waitFor()
    assert.equal(await page.getByRole('navigation', { name: 'Change interface' }).count(), 0)
    const request = page.waitForRequest(
      (request) => request.method() === 'POST' && new URL(request.url()).pathname === '/lab',
    )
    await page.getByRole('button', { name: /Fixture persona/ }).click()
    const form = new URLSearchParams((await request).postData() ?? '')
    assert.equal(form.get('surface'), 'api')
    assert.equal(form.get('mode'), 'connect')
    assert.equal(form.get('operation'), 'createPerson')
    assert.equal(form.get('step'), 'create')
    assert.equal(form.get('generation'), '1')
    assert.equal(form.get('email'), 'fixture@example.test')
  })
  it('keeps a selected interface and useful retry when sandbox loading fails', async (t) => {
    const page = await t.serve(await createTestServer(labFixture().fetch))
    page.setDefaultTimeout(15000)
    await page.goto('/session?surface=api&mode=compare&unavailable=1&operation=listPeople')
    await page.getByRole('heading', { name: 'API lab', exact: true }).waitFor()
    assert.equal(await page.locator('.lab-card').count(), 0)
    await page.getByRole('alert').getByRole('link', { name: 'Try again' }).click()
    assert.equal(new URL(page.url()).searchParams.get('operation'), 'listPeople')
    await page.getByRole('heading', { name: 'Choose a persona', exact: true }).waitFor()
  })
})
