import { chromium, type Locator, type Page } from 'playwright'
import assert from 'node:assert/strict'

// Live end-to-end check of the core hiring loop in the UI lab sandbox, through real clicks:
// create a job with a description -> edit its pipeline -> build and adjust its hiring team -> it is on
// careers with its description -> a visitor applies there -> SOURCE A PROSPECT: create them, add them to a
// talent pool for the job, work them on the sourcing board, convert them to an application -> book and score
// every required interview (the board shows it scheduled; the move preview lists owed feedback first) ->
// move to Offer -> references and verbal offer -> approve (hiring manager), send, get a fresh link, and the
// prospect accepts through it -> mark hired, landing in the Hired column. Start Rails + web first (see
// LOCAL_LAB.md). LAB_URL overrides the address. It writes to the sandbox it signs in to, so run it against a
// local server, not the shared demo people are auditing.
const base = process.env.LAB_URL ?? 'http://127.0.0.1:44100'
// Every run leaves an "E2E Hire <timestamp>" job and candidates behind. On the shared demo that is
// visible to everyone auditing it, so a non-local address needs an explicit opt-in.
if (!/^https?:\/\/(127\.0\.0\.1|localhost)(:\d+)?/.test(base) && process.env.ALLOW_SHARED_DEMO !== '1') {
  console.error(
    `verify:hire writes records. Refusing ${base}; set ALLOW_SHARED_DEMO=1 to run it there anyway.`,
  )
  process.exit(2)
}
const browser = await chromium.launch({ headless: process.env.HEADED !== '1' })
const errors: string[] = []
const title = `E2E Hire ${new Date().toISOString().slice(0, 19).replace(/[-:T]/g, '')}`
const pages: Page[] = []
process.on('uncaughtException', async (error) => {
  const out = process.env.E2E_ARTIFACTS ?? '/tmp'
  for (const [i, page] of pages.entries()) {
    await page.screenshot({ path: `${out}/hire-flow-fail-${i}.png`, fullPage: true }).catch(() => {})
    console.error(
      `page ${i} ${page.url()}\n${(
        await page
          .locator('main')
          .innerText()
          .catch(() => '')
      ).slice(0, 1200)}`,
    )
  }
  console.error(error)
  process.exit(1)
})

// A visitor with no lab session: the careers site and the offer link, as a candidate sees them.
async function visitor(): Promise<Page> {
  const iam = process.env.E2E_IAM_TOKEN
  const context = await browser.newContext({
    viewport: { width: 1280, height: 900 },
    extraHTTPHeaders: iam ? { 'X-Serverless-Authorization': `Bearer ${iam}` } : undefined,
  })
  const page = await context.newPage()
  page.setDefaultTimeout(30_000)
  pages.push(page)
  page.on('pageerror', (error) => errors.push(`visitor: ${error.message}`))
  return page
}

async function persona(name: string): Promise<Page> {
  // A private Cloud Run service: pass an identity token (gcloud auth print-identity-token) as E2E_IAM_TOKEN.
  // Cloud Run checks and strips X-Serverless-Authorization, so the app never sees it.
  const iam = process.env.E2E_IAM_TOKEN
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    extraHTTPHeaders: iam ? { 'X-Serverless-Authorization': `Bearer ${iam}` } : undefined,
  })
  const page = await context.newPage()
  page.setDefaultTimeout(30_000)
  pages.push(page)
  page.on('pageerror', (error) => errors.push(`${name}: ${error.message}`))
  await page.goto(`${base}/session?surface=ui&mode=explore`)
  await page.getByRole('button', { name: new RegExp(name) }).click()
  await page.waitForURL('**/today')
  return page
}

function form(page: Page, intent: string): Locator {
  return page.locator(`form:has(input[name="intent"][value="${intent}"])`)
}

// Wait for the navigation the click causes (POST, then any redirect); waitForLoadState alone returns at
// once on the page that is already loaded and races the submit.
async function navigates(page: Page, action: () => Promise<unknown>) {
  await Promise.all([page.waitForEvent('framenavigated'), action()])
  await page.waitForLoadState('load')
}

async function submit(page: Page, intent: string) {
  await navigates(page, () => form(page, intent).locator('button[type="submit"]').first().click())
}

async function noError(page: Page, step: string) {
  const text = await page.locator('main').innerText()
  const failure = text.match(/(Could not[^\n]*|failed[^\n]*|Error:[^\n]*)/i)
  assert.equal(failure, null, `${step}: ${failure?.[0]}`)
}

const step = (label: string) => console.log(`- ${label}`)

async function moveTo(page: Page, stageKey: string, notice: string) {
  const select = form(page, 'transition').locator('select[name="to_stage_key"]')
  if (!(await select.isVisible()))
    await page.locator('summary', { hasText: 'Move candidate' }).first().click()
  await select.selectOption(stageKey)
  await submit(page, 'transition')
  await page.getByText(notice).waitFor()
}

const riley = await persona('Riley Recruiter')

step('create the job')
await riley.goto(`${base}/jobs/new`)
await riley.getByLabel('Title').fill(title)
await riley.getByLabel('Location').fill('Remote — US')
await riley
  .getByLabel('Job description')
  .fill(
    `${title} at Big Buck\n\nYou will ship the hiring loop end to end.\n\nWhat you will do\n- Own a surface\n- Pair with the team`,
  )
await Promise.all([
  riley.waitForURL(/\/jobs\/[^/?]+\?/),
  riley.getByRole('button', { name: 'Create job' }).click(),
])
await riley.getByText(`Opened ${title}`).waitFor()
const jobUrl = riley.url().split('?')[0]

step('edit the pipeline: add a stage, then remove it')
const addStage = form(riley, 'pipeline').filter({ has: riley.locator('input[name="op"][value="add_stage"]') })
await addStage.locator('input[name="name"]').fill('Reference call')
await navigates(riley, () => addStage.locator('button[type="submit"]').click())
await riley.getByText('Added Reference call.').waitFor()
const stageNames = async () =>
  riley
    .locator('.pipeline-editor tbody tr')
    .evaluateAll((rows) =>
      rows.map(
        (row) => (row.querySelector('input[name="name"]') as HTMLInputElement | null)?.value ?? 'Hired',
      ),
    )
assert.deepEqual(
  (await stageNames()).slice(-3),
  ['Reference call', 'Offer', 'Hired'],
  'a new interview stage goes before Offer; Hired stays last',
)
const removeStage = riley.locator(
  'form:has(input[name="op"][value="remove_stage"]):has(input[name="key"][value="reference-call"])',
)
await navigates(riley, () => removeStage.locator('button[type="submit"]').click())
await riley.getByText('Removed Reference call.').waitFor()

step('build the hiring team')
await riley.goto(`${jobUrl}?tab=settings`)
for (const [person, role] of [
  ['Harper Manager', 'Hiring manager'],
  ['Ivy Interviewer', 'Interviewer'],
] as const) {
  await form(riley, 'team_add').getByLabel('Person').selectOption({ label: person })
  await form(riley, 'team_add').getByLabel('Role on this job').selectOption({ label: role })
  await submit(riley, 'team_add')
  await riley.getByText('Added to the hiring team.').waitFor()
}
const team = await riley.locator('#hiring-team').locator('xpath=..').innerText()
for (const name of ['Riley Recruiter', 'Harper Manager', 'Ivy Interviewer'])
  assert.match(team, new RegExp(name))

step('change a team role, then put it back')
const ivyRole = riley
  .locator('li.queue-item', { hasText: 'Ivy Interviewer' })
  .locator('form:has(input[name="intent"][value="team_role"])')
await ivyRole.locator('select').selectOption('coordinator')
await navigates(riley, () => ivyRole.locator('button[type="submit"]').click())
await riley.getByText('Hiring team role changed.').waitFor()
assert.match(await riley.locator('li.queue-item', { hasText: 'Ivy Interviewer' }).innerText(), /Coordinator/)
await ivyRole.locator('select').selectOption('interviewer')
await navigates(riley, () => ivyRole.locator('button[type="submit"]').click())
await riley.getByText('Hiring team role changed.').waitFor()

step('the job is listed on this sandbox careers page')
await riley.getByRole('link', { name: 'Careers', exact: true }).first().click()
assert.match(riley.url(), /slug=big-buck-lab-ui/)
await riley.getByText(title).first().waitFor()
assert.match(await riley.locator('.careers-role', { hasText: title }).innerText(), /Remote — US · Full-time/)
await navigates(riley, () =>
  riley.locator('.careers-role', { hasText: title }).locator('a.careers-role-link').click(),
)
await riley.getByText('You will ship the hiring loop end to end.').waitFor()
const jobPageUrl = riley.url()

const candidateName = `Casey Candidate ${title.slice(-6)}`
step(`${candidateName} applies from the public careers page`)
const casey = await visitor()
await casey.goto(jobPageUrl)
await navigates(casey, () => casey.getByRole('link', { name: 'Apply for this role' }).click())
await casey.getByLabel('Full name').fill(candidateName)
await casey.getByLabel('Email').fill(`casey-${Date.now()}@example.test`)
for (const select of await casey.locator('form select[required]').all()) {
  const value = await select.locator('option:not([value=""])').first().getAttribute('value')
  if (value) await select.selectOption(value)
}
for (const field of await casey
  .locator(
    'form textarea[required], form input[required]:not([type="hidden"]):not([name="display_name"]):not([name="email"])',
  )
  .all()) {
  if (!(await field.inputValue())) await field.fill('https://example.test')
}
await navigates(casey, () => casey.getByRole('button', { name: 'Submit application' }).click())
await casey.getByRole('heading', { name: 'Application received' }).waitFor()

step('the visitor’s application is in the job')
await riley.goto(`${jobUrl}?tab=applications`)
await riley.locator('a[href*="/applications/"]', { hasText: candidateName }).waitFor()
await casey.context().close()

const prospectName = `Pat Prospect ${title.slice(-6)}`
step(`source ${prospectName}: create the person`)
await riley.goto(`${base}/people/new`)
await riley.getByLabel('Full name').fill(prospectName)
await riley.getByLabel('Email').fill(`pat-${Date.now()}@example.test`)
await navigates(riley, () => riley.getByRole('button', { name: 'Create person' }).click())
await riley.getByText(`Created ${prospectName}`).waitFor()

step('start a talent pool for the job and add the prospect')
await riley.goto(`${base}/pools/new`)
await riley.getByLabel('Name').fill(`${title} pool`)
await riley.getByLabel('Linked job (optional)').selectOption({ label: title })
await navigates(riley, () => riley.getByRole('button', { name: 'Create pool' }).click())
await riley.locator('summary', { hasText: 'Add to pool' }).click()
const addMember = form(riley, 'add_member')
const option = await addMember
  .locator('select[name="person_id"] option', { hasText: prospectName })
  .getAttribute('value')
assert.ok(option, 'the new prospect can be added to the pool')
await addMember.locator('select[name="person_id"]').selectOption(option!)
await submit(riley, 'add_member')
await riley.getByText('Member added').waitFor()

step('work the prospect on the sourcing board, then convert them to an application')
await navigates(riley, () => riley.locator('a.board-card-name', { hasText: prospectName }).click())
const nextStage = form(riley, 'transition').locator('select[name="to_stage_key"]')
const nextKey = await nextStage.locator('option').first().getAttribute('value')
await nextStage.selectOption(nextKey!)
await submit(riley, 'transition')
await riley
  .getByText(/^Moved to /)
  .first()
  .waitFor()
await submit(riley, 'convert')
await riley.getByText('Converted to an application on the job.').waitFor()
await navigates(riley, () => riley.getByRole('link', { name: /Open converted application/ }).click())
const applicationUrl = riley.url().split('?')[0]
assert.match(applicationUrl, /\/applications\//)

step(`move ${prospectName} to Onsite`)
await moveTo(riley, 'onsite', 'Moved to Onsite.')

const interviews = (await form(riley, 'preview_booking')
  .locator('select[name="interview_key"] option')
  .evaluateAll((options) =>
    options.map((option) => (option as HTMLOptionElement).value).filter(Boolean),
  )) as string[]
assert.ok(interviews.length > 0, 'the interview plan offers interviews to schedule')
step('the board move preview lists the feedback still owed, and the move stays available')
const applicationId = applicationUrl.split('/').pop()!
await riley.goto(`${jobUrl}?tab=pipeline&application_id=${applicationId}&to_stage_key=offer`)
const owed = riley.locator('.notice-warn', { hasText: 'Feedback is still missing in Onsite' })
await owed.waitFor()
assert.equal(
  await riley.getByRole('button', { name: 'Confirm move' }).isDisabled(),
  false,
  'missing feedback warns and does not hold the move',
)
await riley.goto(applicationUrl)

for (const key of interviews) {
  step(`book and score the ${key} interview`)
  const booking = form(riley, 'preview_booking')
  await booking.locator('select[name="interview_key"]').selectOption(key)
  // Feedback is assigned to the interviewers booked onto the interview, so Riley books herself and
  // then writes her own scorecard.
  await booking.locator('select[name="interviewer_user_id"]').selectOption({ label: 'Riley Recruiter' })
  await submit(riley, 'preview_booking')
  await form(riley, 'book_panel').locator('input[name="booking_token"]').first().check()
  await submit(riley, 'book_panel')
  await noError(riley, `book ${key}`)
  // The form for feedback she still owes; earlier scorecards keep a collapsed edit form of their own.
  const card = riley.locator('.scorecard-own form').first()
  await card.locator('select[name="rating"]').selectOption('yes')
  for (const select of await card.locator('select[name^="attribute_"]').all()) await select.selectOption('4')
  await card.locator('[name="notes"]').fill('E2E: solid signal.')
  await navigates(riley, () => card.locator('button[type="submit"]').click())
  await riley.getByText('Feedback submitted.').waitFor()
}

step('the board shows the candidate scheduled, and the move preview no longer warns')
await riley.goto(`${jobUrl}?tab=pipeline&application_id=${applicationId}&to_stage_key=offer`)
await riley.getByRole('heading', { name: 'Move preview' }).waitFor()
assert.equal(await riley.locator('.notice-warn', { hasText: 'Feedback is still missing' }).count(), 0)
assert.equal(await riley.getByRole('button', { name: 'Confirm move' }).isDisabled(), false)
await riley.goto(`${jobUrl}?tab=applications`)
assert.match(
  await riley.locator('tr', { hasText: prospectName }).innerText(),
  /E[SD]T/,
  'next interview time is listed',
)
await riley.goto(applicationUrl)

step('move to Offer')
await moveTo(riley, 'offer', 'Moved to Offer.')

step('create the offer and submit it for approval')
await form(riley, 'create_offer').locator('input[name="base_salary"]').fill('185000')
await submit(riley, 'create_offer')
await noError(riley, 'create offer')
await navigates(riley, () => riley.locator('a[href*="/offers/"]').first().click())
await riley.getByRole('heading', { name: /Offer for/ }).waitFor()
const offerUrl = riley.url().split('?')[0]

step('references and the verbal offer')
for (const [item, state, notice] of [
  ['references', 'complete', 'References: Complete.'],
  ['verbal', 'made', 'Verbal offer: Verbal offer made.'],
] as const) {
  const checklist = riley.locator(
    `form:has(input[name="intent"][value="checklist"]):has(input[name="item"][value="${item}"])`,
  )
  await checklist.locator('select[name="state"]').selectOption(state)
  await navigates(riley, () => checklist.locator('button[type="submit"]').click())
  await riley.getByText(notice).waitFor()
}
if (await form(riley, 'submit').count()) {
  await submit(riley, 'submit')
  await noError(riley, 'submit offer')
}

if (await riley.locator('.chip-row').getByText('Waiting for approval').count()) {
  step('Harper Manager approves')
  const harper = await persona('Harper Manager')
  await harper.goto(offerUrl)
  await submit(harper, 'approve')
  await harper.getByText('Approved').first().waitFor()
  await harper.context().close()
  await riley.goto(offerUrl)
}

step('send the offer letter')
await submit(riley, 'send')
await riley.getByText('Offer sent').waitFor()

step('get a fresh candidate link for the sent offer')
await submit(riley, 'resend')
await riley.getByText(/^Offer resent/).waitFor()
const acceptHref = await riley
  .locator('a[href^="/offers/"]:not([href^="/offers/view"])')
  .first()
  .getAttribute('href')
assert.ok(acceptHref, 'the offer page shows the candidate accept link')

step(`${prospectName} reads the letter and accepts through the link`)
const pat = await visitor()
await pat.goto(new URL(acceptHref!, base).toString())
assert.match(await pat.locator('[aria-label="Offer letter"]').innerText(), /185,000/, 'salary is formatted')
await pat.getByLabel('Type your full name to accept').fill(prospectName)
await navigates(pat, () => pat.getByRole('button', { name: 'Accept offer' }).click())
await pat.getByRole('heading', { name: 'Offer accepted' }).waitFor()
await pat.context().close()

step('mark hired from the offer')
await riley.goto(offerUrl)
if (await form(riley, 'hire').count()) {
  await submit(riley, 'hire')
  await riley.locator('.notice', { hasText: 'Candidate marked hired.' }).waitFor()
}
await riley.goto(applicationUrl)
assert.match(await riley.locator('main').innerText(), /· hired/i)
const currentStage = await riley
  .locator('[aria-label="Candidate pipeline"] [aria-current="step"]')
  .innerText()
assert.match(currentStage, /Hired/, 'a hired candidate sits in the Hired stage')

step('the job board shows them in the Hired column')
await riley.goto(`${jobUrl}?tab=pipeline`)
const hiredColumn = riley.locator('section.board-col[aria-label="Hired"]')
await hiredColumn.getByText(prospectName).waitFor()

assert.deepEqual(errors, [], 'no page errors')
console.log(`PASS: prospect ${prospectName} sourced and hired for "${title}" end to end in the UI.`)
await browser.close()
