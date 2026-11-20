import * as assert from 'remix/assert'
import { createTestServer } from 'remix/node-fetch-server/test'
import { describe, it } from 'remix/test'

import { loadBigBuckFixture, startMockRailsApi } from '../test/mock-rails-api.ts'
import { router } from './router.ts'
import { routes } from './routes.ts'

// Set SHOTS to a directory to keep a screenshot of each state this test reaches.
const shots = process.env.SHOTS
const shot = async (page: { screenshot(options: object): Promise<unknown> }, name: string) => {
  if (shots) await page.screenshot({ path: `${shots}/${name}.png`, fullPage: true })
}

describe('CRM editing', () => {
  it('builds a sequence step by step and reorders it by dragging', async (t) => {
    const api = await startMockRailsApi()
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await page.setViewportSize({ width: 1280, height: 900 })
    await page.goto(routes.login.index.href())
    await page.getByLabel('Work email').fill(api.fixture.users.admin.email)
    await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
    await page.waitForURL((url) => url.pathname === routes.today.href())

    // Creating a sequence asks for a name only and lands in its editor.
    await page.goto(routes.sequencesIndex.href())
    await page.getByText('Create or enroll', { exact: true }).click()
    assert.equal(await page.getByLabel('Key').count(), 0)
    await page.getByLabel('Name').fill('Staff backend outreach')
    await page.getByRole('button', { name: 'Create and add steps' }).click()
    await page.getByRole('heading', { name: 'Staff backend outreach' }).waitFor()
    await page
      .getByText(
        'Created Staff backend outreach. It starts with one email: change it, or add more steps below.',
      )
      .waitFor()

    const add = page.getByRole('group', { name: 'Add a step' })
    const steps = page.locator('.sequence-step .title')
    const addStep = async (kind: string, fill?: () => Promise<void>) => {
      await add.getByText(kind, { exact: true }).click()
      await fill?.()
      await add.getByRole('button', { name: `Add ${kind.toLowerCase()}` }).click()
      await page.getByText('Steps updated.').waitFor()
    }
    // Rails starts every sequence with one email, and a sequence cannot have none: the only step stays.
    assert.deepEqual(await steps.allTextContents(), ['1. Send email'])
    assert.equal(await page.getByRole('button', { name: 'Remove step 1' }).isDisabled(), true)
    await page.getByText("A sequence needs at least one step, so this one can't be removed.").waitFor()
    await addStep('Wait', () => add.locator('details[open] input[name=days]').fill('3'))
    await addStep('LinkedIn task')
    await addStep('Email', async () => {
      await add.locator('details[open] select[name=template_key]').selectOption('follow-up')
      // Send the last email from a teammate's own mailbox.
      await add
        .locator('details[open] select[name=send_as_user_id]')
        .selectOption({ label: 'recruiter@bigbuck.test' })
    })
    assert.deepEqual(await steps.allTextContents(), [
      '1. Send email',
      '2. Wait',
      '3. LinkedIn task',
      '4. Send email',
    ])
    await page.getByText('Follow-up · from recruiter@bigbuck.test').waitFor()
    await page.getByText('Send a LinkedIn message · sequence waits until it is done').waitFor()
    await shot(page, 'sequence-editor')

    // Only one "Add a step" form is open at a time.
    await add.getByText('Wait', { exact: true }).click()
    await add.getByText('Call task', { exact: true }).click()
    assert.equal(await add.locator('details[open]').count(), 1)
    await shot(page, 'sequence-add-step')

    // Edit a step in place: its type and position stay, its fields change.
    await page.getByLabel('Edit step 2').click()
    const edit = page.locator('.sequence-step').nth(1)
    await edit.getByLabel('Days to wait').fill('5')
    await shot(page, 'sequence-edit-step')
    await edit.getByRole('button', { name: 'Save step' }).click()
    await page.getByText('Steps updated.').waitFor()
    await page.locator('.sequence-step').nth(1).getByText('5 days').waitFor()

    // Drag the LinkedIn task above the wait.
    await page.locator('[data-drag-ready]').first().waitFor()
    await page
      .locator('.sequence-step')
      .nth(2)
      .dragTo(page.locator('.sequence-step').nth(1), {
        targetPosition: { x: 80, y: 4 },
      })
    await page.getByText('Steps updated.').waitFor()
    assert.deepEqual(await steps.allTextContents(), [
      '1. Send email',
      '2. LinkedIn task',
      '3. Wait',
      '4. Send email',
    ])
    // The arrow buttons do the same move without a pointer.
    await page.getByRole('button', { name: 'Move step 2 down' }).click()
    await page.getByText('Steps updated.').waitFor()
    assert.equal((await steps.allTextContents())[2], '3. LinkedIn task')
    // What the API was left holding.
    const stored = (api.fixture as unknown as { sequences: Array<Record<string, any>> }).sequences
    const sequence = stored.find((row) => row.name === 'Staff backend outreach')!
    assert.deepEqual(
      sequence.steps.map((step: { type: string }) => step.type),
      ['email', 'wait', 'task', 'email'],
    )
    assert.equal(sequence.steps[1].days, 5)
    assert.equal(sequence.steps[2].task_type, 'linkedin')
    assert.equal(sequence.steps[2].pause_until_done, true)
    assert.ok(sequence.steps[3].send_as_user_id)
    assert.match(sequence.key, /^staff-backend-outreach-[a-z0-9]{4}$/)

    // Remove down to one step. The last one cannot go, and a forced request gets a plain reason, not a 5xx.
    for (const position of [4, 3, 2]) {
      await page.getByRole('button', { name: `Remove step ${position}` }).click()
      await page.getByText('Steps updated.').waitFor()
    }
    assert.deepEqual(await steps.allTextContents(), ['1. Send email'])
    assert.equal(await page.getByRole('button', { name: 'Remove step 1' }).isDisabled(), true)
    await page.evaluate(() => {
      document.querySelector<HTMLButtonElement>('button[aria-label="Remove step 1"]')!.disabled = false
    })
    await page.getByRole('button', { name: 'Remove step 1' }).click()
    await page.getByText('Could not save the steps: A sequence needs at least one step.').waitFor()
    assert.deepEqual(await steps.allTextContents(), ['1. Send email'])
    assert.equal(sequence.steps.length, 1)
  })

  it('moves a prospect between pool stages by dragging the card', async (t) => {
    const fixture = loadBigBuckFixture()
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await page.setViewportSize({ width: 1280, height: 900 })
    await page.goto(routes.login.index.href())
    await page.getByLabel('Work email').fill(fixture.users.admin.email)
    await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
    await page.waitForURL((url) => url.pathname === routes.today.href())

    const pool = fixture.projects.find((project) => project.name === 'Platform warm bench')!
    await page.goto(routes.poolsShow.index.href({ projectId: pool.id }))
    const column = (name: string) => page.locator('.board-col', { has: page.getByRole('heading', { name }) })
    const count = async (name: string) => Number(await column(name).locator('.board-col-count').textContent())
    const before = { prospect: await count('Prospect'), replied: await count('Replied') }
    await column('Prospect').getByRole('link', { name: 'Cara Nguyen' }).waitFor()
    await page.locator('[data-drag-ready]').waitFor()
    await shot(page, 'pool-board-before')

    await column('Prospect')
      .locator('.board-card', { hasText: 'Cara Nguyen' })
      // Aim at the column heading: it is on screen, so the page does not scroll mid-drag.
      .dragTo(column('Replied').locator('.board-col-head'))
    await page.getByText('Moved Cara Nguyen to Replied.').waitFor()
    await column('Replied').getByRole('link', { name: 'Cara Nguyen' }).waitFor()
    assert.equal(await count('Prospect'), before.prospect - 1)
    assert.equal(await count('Replied'), before.replied + 1)
    await shot(page, 'pool-board-after')

    // Dropping a card on its own column changes nothing and sends nothing.
    await column('Replied')
      .locator('.board-card', { hasText: 'Cara Nguyen' })
      .dragTo(column('Replied').locator('.board-col-head'))
    assert.equal(await count('Replied'), before.replied + 1)
    assert.equal(await page.locator('[aria-busy="true"]').count(), 0)

    // The card is still a link to the prospect, for keyboards, touch and anyone who would rather click.
    await column('Replied').getByRole('link', { name: 'Cara Nguyen' }).click()
    await page.getByRole('heading', { name: 'Cara Nguyen' }).waitFor()

    // Without permission to manage the pool there is nothing to drag.
    await page.context().clearCookies()
    await page.goto(routes.login.index.href())
    await page.getByLabel('Work email').fill(fixture.users.hiring_manager!.email)
    await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
    await page.waitForURL((url) => url.pathname === routes.today.href())
    await page.goto(routes.poolsShow.index.href({ projectId: pool.id }))
    await page.getByRole('heading', { name: 'Sourcing board' }).waitFor()
    await page.getByText('Select a prospect to review them.').waitFor()
    assert.equal(await page.locator('[data-drag-item]').count(), 0)
    assert.equal(await page.locator('form[data-drag-form]').count(), 0)
  })
  it('moves and enrolls several prospects from the pool board, with a review before anything is sent', async (t) => {
    const fixture = loadBigBuckFixture()
    // One checked prospect cannot be emailed: the review must say so instead of failing later.
    const lane = fixture.people.find((person) => person.display_name === 'Lane Ito')! as Record<string, any>
    lane.do_not_contact = true
    fixture.rest_responses = {
      '/v1/analytics/funnel': {
        total_applications: 12,
        hired: 2,
        rejected: 3,
        active_by_stage: { phone_screen: 4 },
      },
      '/v1/analytics/sourcing': {
        active_sequences: 1,
        outbound_messages: 40,
        inbound_replies: 9,
        reply_rate: 0.225,
        enrollments_by_status: { active: 5, replied: 4 },
      },
      '/v1/analytics/outreach': {
        enrolled: 30,
        contacted: 28,
        replied: 7,
        reply_rate: 0.25,
        by_classification: { interested: 3, question: 1, not_interested: 2, other: 1, out_of_office: 4 },
        positive_replies: 4,
        applied: 2,
        hired: 1,
      },
    }
    const api = await startMockRailsApi(fixture)
    t.after(() => api.close())
    process.env.RAILS_API_URL = api.baseUrl
    const page = await t.serve(await createTestServer(router.fetch))
    page.setDefaultTimeout(15_000)
    await page.setViewportSize({ width: 1280, height: 900 })
    await page.goto(routes.login.index.href())
    await page.getByLabel('Work email').fill(fixture.users.admin.email)
    await page.getByRole('button', { name: 'Sign in with email (demo)' }).click()
    await page.waitForURL((url) => url.pathname === routes.today.href())

    await page.goto(routes.sequencesIndex.href())
    await page.getByText('Create or enroll', { exact: true }).click()
    await page.getByLabel('Name').fill('Platform nudge')
    await page.getByRole('button', { name: 'Create and add steps' }).click()
    await page.getByRole('heading', { name: 'Platform nudge' }).waitFor()

    const pool = fixture.projects.find((project) => project.name === 'Platform warm bench')!
    await page.goto(routes.poolsShow.index.href({ projectId: pool.id }))
    const column = (name: string) => page.locator('.board-col', { has: page.getByRole('heading', { name }) })
    const count = async (name: string) => Number(await column(name).locator('.board-col-count').textContent())
    const before = { prospect: await count('Prospect'), replied: await count('Replied') }
    const bulk = page.getByRole('form', { name: 'Actions for checked prospects' })

    // Nothing checked: a plain reason, and nobody moves.
    await bulk.getByLabel('Move checked to').selectOption({ label: 'Replied' })
    await bulk.getByRole('button', { name: 'Move checked' }).click()
    await page.getByText('Check at least one prospect on the board first.').waitFor()
    assert.equal(await count('Prospect'), before.prospect)

    await page.getByLabel('Select Cara Nguyen').check()
    await page.getByLabel('Select Paige Underwood').check()
    await shot(page, 'pool-bulk-checked')
    await bulk.getByLabel('Move checked to').selectOption({ label: 'Replied' })
    await bulk.getByRole('button', { name: 'Move checked' }).click()
    await page.getByText('Moved 2 prospects to Replied.').waitFor()
    assert.equal(await count('Prospect'), before.prospect - 2)
    assert.equal(await count('Replied'), before.replied + 2)

    // Enroll three: the sequence page reviews them first and names who is skipped and why.
    await page.getByLabel('Select Cara Nguyen').check()
    await page.getByLabel('Select Lane Ito').check()
    await page.getByLabel('Select Dana Torres').check()
    await bulk.getByLabel('Enroll checked in').selectOption({ label: 'Platform nudge' })
    await bulk.getByRole('button', { name: 'Review and enroll' }).click()
    await page.getByRole('heading', { name: 'Platform nudge' }).waitFor()
    const review = page.getByRole('form', { name: 'Enrollment review' })
    await review.getByText('You selected 3 people.').waitFor()
    await review.getByText('2 will be enrolled, 1 skipped.', { exact: false }).waitFor()
    await review.getByText('Marked do not contact').waitFor()
    assert.equal((api.fixture as unknown as { enrollments?: unknown[] }).enrollments?.length ?? 0, 0)
    await shot(page, 'sequence-enroll-review')
    await review.getByRole('button', { name: 'Enroll checked people' }).click()
    await page.getByText('Enrolled 2.').waitFor()
    const enrolled = (api.fixture as unknown as { enrollments: Array<{ person_id: string }> }).enrollments
    assert.equal(enrolled.length, 2)
    assert.ok(!enrolled.some((row) => row.person_id === lane.id))

    // People list: the same review, reached from checked rows.
    await page.goto(routes.peopleIndex.href())
    await page.getByRole('button', { name: 'Review and enroll' }).waitFor()
    assert.equal(await page.getByRole('button', { name: 'Enroll selected' }).count(), 0)

    // Analytics shows what the outreach produced, in words rather than stored keys.
    await page.goto(routes.analytics.href())
    const outreach = page.getByRole('region', { name: 'Outreach results' })
    await outreach.getByText('25% of contacted').waitFor()
    await outreach.getByText('Asked a question', { exact: true }).waitFor()
    await outreach.getByText('Out of office', { exact: true }).waitFor()
    await page.getByText('Active in Phone screen').waitFor()
    assert.equal(await page.getByText('phone_screen').count(), 0)
    await shot(page, 'analytics-outreach')
  })
})
