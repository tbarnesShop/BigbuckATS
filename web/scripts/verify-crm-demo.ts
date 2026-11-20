import { chromium, type Page } from 'playwright'
import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

// Live end-to-end check of the CRM demo on a NON-demo org that `bin/rails crm:demo_seed` filled.
// Steps (the web app drives what has a page; the rest goes through the same REST API agents use):
//   2  search "staff backend, Philadelphia, tag:go, not contacted in 90 days" in the UI, save it, make a smart pool
//   3  build a 4-step sequence (email -> wait -> LinkedIn task -> email as a teammate), review the enrollment
//      (25 will enroll, 3 skipped with reasons), commit it
//   4  answer two emails from the Test inbox; replies reach the person feed, stop their sequences, one is "interested"
//   5  add a note and a follow-up on the person page; the follow-up shows on Today
//   6  convert the interested prospect to an application; the source stays "sourced"
//   7  the sourcing agent proposes people for the open job with per-criterion reasons and drafted openers; the
//      recruiter approves 6; the proposals are audited as agent-on-behalf-of-recruiter
// Needs Rails (:3000) and web (:44100, started with BIGBUCK_TOKEN) running, and CRM_OWNER_TOKEN, CRM_SAM_USER_ID.
// It writes to the org it points at; run it against a local server and a throwaway org.
// A non-demo org signs in through Google; the e2e uses the same one-time handoff code that flow redirects with.
const repoRoot = fileURLToPath(new URL('../../', import.meta.url))
const web = process.env.LAB_URL ?? 'http://127.0.0.1:44100'
const api = process.env.RAILS_API_URL ?? 'http://127.0.0.1:3000'
const token = process.env.CRM_OWNER_TOKEN
const samUserId = process.env.CRM_SAM_USER_ID
if (!token || !samUserId || !process.env.CRM_ORG) {
  console.error(
    'Set CRM_OWNER_TOKEN, CRM_SAM_USER_ID and CRM_ORG (script/crm-demo-org.sh writes them) (see LOCAL_LAB.md / crm:demo_seed).',
  )
  process.exit(2)
}
if (!/^https?:\/\/(127\.0\.0\.1|localhost)(:\d+)?/.test(web) && process.env.ALLOW_SHARED_DEMO !== '1') {
  console.error(`verify:crm writes records. Refusing ${web}.`)
  process.exit(2)
}

type Json = Record<string, any>
let seq = 0
async function call(method: string, path: string, body?: unknown): Promise<Json> {
  const res = await fetch(`${api}/v1${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': `crm-e2e-${Date.now()}-${seq++}`,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  const text = await res.text()
  const json = text ? JSON.parse(text) : {}
  assert.ok(res.ok, `${method} ${path} -> ${res.status} ${text.slice(0, 400)}`)
  return json
}

const browser = await chromium.launch({ headless: process.env.HEADED !== '1' })
const page: Page = await browser.newPage({ viewport: { width: 1440, height: 1000 } })
page.setDefaultTimeout(30_000)
const errors: string[] = []
page.on('pageerror', (error) => errors.push(error.message))
const step = (n: number, text: string) => console.log(`\n[${n}] ${text}`)
const shots = process.env.E2E_ARTIFACTS ?? '/tmp'

process.on('uncaughtException', async (error) => {
  await page.screenshot({ path: `${shots}/crm-demo-fail.png`, fullPage: true }).catch(() => {})
  console.error(
    `page ${page.url()}\n${(
      await page
        .locator('main')
        .innerText()
        .catch(() => '')
    ).slice(0, 1500)}`,
  )
  console.error(error)
  process.exit(1)
})

// ---- 2. Search, save, smart pool -------------------------------------------------------------
step(2, 'search, save, smart pool')
const code = execFileSync(`${repoRoot}script/crm-login-code.sh`, [process.env.CRM_ORG ?? ''], {
  encoding: 'utf8',
}).trim()
await page.goto(`${web}/session/login?code=${code}`)
await page.waitForURL('**/today')
await page.goto(`${web}/people`)
const search = page.locator('form[aria-label="Find people"]')
await search.locator('input[name="q"]').fill('staff backend')
await search.locator('input[name="location"]').fill('Philadelphia')
await search.locator('input[name="tag"]').fill('go')
await search.locator('input[name="not_contacted_days"]').fill('90')
await Promise.all([
  page.waitForLoadState('load'),
  search.getByRole('button', { name: 'Search people' }).click(),
])
await page.getByText('28 people match').waitFor()
console.log('  UI shows 28 people match')

await page.getByText('Save this search').first().click()
const saveForm = page.locator('form:has(input[name="intent"][value="save_search"])')
await saveForm.locator('input[name="name"]').fill('Staff backend, Philly, go')
await Promise.all([page.waitForLoadState('load'), saveForm.getByRole('button').click()])
await page.getByText('Saved “Staff backend, Philly, go”').waitFor()
const saved = (await call('GET', '/saved_searches')).data.find(
  (s: Json) => s.name === 'Staff backend, Philly, go',
)
assert.ok(saved, 'saved search exists')
assert.equal(saved.filters.tag, 'go')

const pool = await call('POST', '/projects', {
  project: { name: 'Staff backend (smart)', saved_search_id: saved.id },
})
const added = await call('POST', `/projects/${pool.id}/people`, {})
assert.equal(added.added, 28)
assert.equal((await call('POST', `/projects/${pool.id}/people`, {})).added, 0, 'refresh adds nobody twice')
console.log('  smart pool has 28 members; refresh is idempotent')

// ---- 3. Sequence, review, enroll -------------------------------------------------------------
step(3, 'sequence, enrollment review')
const sequence = await call('POST', '/sequences', {
  sequence: {
    key: `staff-backend-${Date.now()}`,
    name: 'Staff backend outreach',
    steps: [
      { type: 'email', template_key: 'starter-intro' },
      { type: 'wait', days: 3 },
      { type: 'task', title: 'Connect on LinkedIn', task_type: 'linkedin' },
      { type: 'email', template_key: 'starter-follow-up', send_as_user_id: samUserId },
    ],
  },
})
assert.equal(sequence.steps.length, 4)
assert.ok(
  sequence.steps.every((s: Json) => s.id),
  'every step has a stable id',
)

const plan = await call('POST', `/sequences/${sequence.id}/enrollment_plan`, { saved_search_id: saved.id })
assert.equal(plan.counts.will_enroll, 25)
assert.deepEqual(plan.counts.skipped, { active_enrollment: 1, company_dnc: 1, do_not_contact: 1 })
console.log('  plan: 25 will enroll; skipped', JSON.stringify(plan.counts.skipped))

const preview = await call(
  'GET',
  `/sequences/${sequence.id}/preview?person_id=${plan.will_enroll[0].person_id}`,
)
assert.equal(preview.steps.filter((s: Json) => s.type === 'email').length, 2)

const enrolled = await call('POST', `/sequences/${sequence.id}/enroll_planned`, { saved_search_id: saved.id })
assert.equal(enrolled.enrolled, 25)
assert.equal(enrolled.failed, 0)
const stats = await call('GET', `/sequences/${sequence.id}/stats`)
assert.equal(stats.steps[0].messages.sent, 25, 'first email sent to all 25 from the Test mailbox')
console.log('  25 enrolled, 25 first emails sent')

// ---- 4. Replies --------------------------------------------------------------------------------
step(4, 'replies from the Test inbox')
const mailboxes = (await call('GET', '/mailboxes')).data.filter((m: Json) => m.provider === 'sandbox')
const owner = mailboxes.find((m: Json) => m.user_id !== samUserId) ?? mailboxes[0]
const sent = (await call('GET', `/mailboxes/${owner.id}/messages`)).data.filter(
  (m: Json) => m.direction === 'outbound' && !m.answered,
)
assert.ok(sent.length >= 2, 'outbound mail waits in the Test inbox')
const replied: string[] = []
for (const message of sent.slice(0, 2)) {
  await call('POST', `/mailboxes/${owner.id}/simulate`, { message_id: message.id, kind: 'reply' })
  replied.push(message.to_address)
}
const people = (await call('GET', `/people?q=${encodeURIComponent(replied[0])}`)).data
const target = people.find((p: Json) => p.primary_email === replied[0])
assert.ok(target, 'replying person found')
const feed = (await call('GET', `/people/${target.id}/feed`)).data
const inbound = feed.find((item: Json) => item.direction === 'inbound')
assert.ok(inbound, 'the reply is on the person feed')
assert.equal(inbound.classification, 'interested', 'rules classify the reply as interested')
const enrollments = (await call('GET', `/sequences/${sequence.id}/enrollments`)).data
const stopped = enrollments.filter((e: Json) => e.status === 'stopped' && e.stop_reason === 'reply')
assert.equal(stopped.length, 2, 'both replies stopped their sequences')
console.log('  2 replies on the feed, sequences stopped, first classified interested')

// ---- 5. Note + follow-up -----------------------------------------------------------------------
step(5, 'note and follow-up on the person page')
await page.goto(`${web}/people/${target.id}?tab=activity`)
await page.getByText('Activity').first().waitFor()
await page.getByText('open to a quick chat').first().waitFor()
await page.getByRole('group', { name: 'Actions' }).locator('summary', { hasText: /^Note/ }).click()
const noteForm = page.locator('form:has(input[name="intent"][value="add_note"])')
await noteForm
  .locator('textarea[name="body"]')
  .fill('Prefers a call after 4pm ET. Mentioned interest in infra.')
await Promise.all([page.waitForLoadState('load'), noteForm.getByRole('button', { name: 'Add note' }).click()])
await page.getByText('Prefers a call after 4pm ET').first().waitFor()
await page
  .getByRole('group', { name: 'Actions' })
  .locator('summary', { hasText: /^Follow-up/ })
  .click()
const taskForm = page.locator('form:has(input[name="intent"][value="add_task"])')
await taskForm.locator('input[name="title"]').fill('Call back this afternoon')
await taskForm.locator('input[name="due_on"]').fill(new Date().toISOString().slice(0, 10))
await Promise.all([
  page.waitForLoadState('load'),
  taskForm.getByRole('button', { name: 'Add follow-up' }).click(),
])
await page.goto(`${web}/today`)
await page.locator('#follow-ups').getByText('Call back this afternoon').first().waitFor()
console.log('  note on the feed; follow-up shows on Today')

// ---- 6. Convert ----------------------------------------------------------------------------------
step(6, 'convert the interested prospect')
const member = (await call('GET', `/project_members?project_id=${pool.id}&person_id=${target.id}`)).data[0]
assert.ok(member, 'prospect is a pool member')
const job = (await call('GET', '/jobs')).data.find((j: Json) => j.title === 'Staff Backend Engineer')
assert.ok(job, 'open job exists')
const converted = await call('POST', `/project_members/${member.id}/convert`, { job_id: job.id })
assert.ok(converted.application.id)
const after = await call('GET', `/people/${target.id}`)
assert.equal(after.source, 'sourced', 'source is kept through conversion')
console.log('  converted to an application; source stays "sourced"')

// ---- 7. Sourcing agent -------------------------------------------------------------------------
step(7, 'sourcing agent proposes, recruiter approves')
const agents = await call('GET', '/agents')
const agent =
  agents.data.find((a: Json) => a.name === 'Sourcing agent') ??
  (await call('POST', '/agents', {
    agent: {
      name: 'Sourcing agent',
      scopes: ['people:read', 'jobs:read'],
      description: 'Rediscovers silver medalists',
    },
  }))
const criteria = await call('GET', `/jobs/${job.id}/rediscovery/criteria`)
assert.equal(criteria.criteria.length, 3)
const run = await call('POST', `/jobs/${job.id}/sourcing_agent/run`, {
  sequence_id: sequence.id,
  agent_id: agent.id,
  limit: 10,
})
assert.equal(run.policy, 'approval_required', 'default policy: nothing sends without approval')
assert.equal(run.proposed.length, 10)
assert.equal(run.auto_enrolled, 0)
const pending = (await call('GET', `/agent_proposals?status=pending&job_id=${job.id}`)).data
assert.equal(pending.length, 10)
assert.ok(pending[0].draft_opener.startsWith('Hi '), 'drafted opener')
assert.ok(
  pending[0].rationale.verdicts.length === 3 && pending[0].rationale.verdicts[0].evidence.length > 0,
  'per-criterion evidence',
)
const approved = await call('POST', '/agent_proposals/bulk_approve', {
  ids: pending.slice(0, 6).map((p: Json) => p.id),
})
assert.equal(approved.approved, 6)
assert.equal((await call('GET', `/agent_proposals?status=approved&job_id=${job.id}`)).data.length, 6)
console.log('  10 proposed with openers + evidence; 6 approved and enrolled')

// The same loop through the web UI: Proposals, Rediscovery and the enrollment review.
step(8, 'proposals, rediscovery and enrollment review in the UI')
await page.goto(`${web}/proposals`)
const queued = await page.locator('.queue-item').count()
assert.equal(queued, 4, 'the four unapproved proposals are listed')
await page.getByRole('button', { name: 'Approve', exact: true }).first().click()
await page.getByText('Approved and enrolled.').waitFor()
assert.equal(await page.locator('.queue-item').count(), 3, 'approving one removes it from the queue')
await page.goto(`${web}/jobs/${job.id}/rediscovery`)
await page.getByText('What good looks like').waitFor()
assert.ok((await page.locator('.queue-item').count()) > 0, 'rediscovery queue has candidates')
await page.goto(`${web}/sequences/view/${sequence.id}`)
const planForm = page.locator('form:has(input[value="plan"])')
await planForm.locator('select[name=selection]').selectOption({ index: 1 })
await planForm.getByRole('button', { name: /Review who/ }).click()
await page.getByLabel('Enrollment review').waitFor()
console.log('  proposal approved, rediscovery queue and enrollment review render')

// The audit trail is checked from the database side by the caller (see LOCAL_LAB.md): actor_type=agent,
// on_behalf_of = the recruiter, for agent_proposal.created.
await page.goto(`${web}/people`)
assert.deepEqual(errors, [], `page errors: ${errors.join('; ')}`)
await browser.close()
console.log('\nCRM demo verified.')
