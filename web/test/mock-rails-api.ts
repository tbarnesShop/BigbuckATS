import type {
  ApplicationFormPayload,
  PostingQuestion,
  JobPosting,
  QuestionTemplate,
} from '../app/data/api.ts'
import * as http from 'node:http'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

export type BigBuckFixture = {
  // Isolated acceptance overrides, including partial GraphQL failure and capped slices.
  graphql_responses?: Record<string, unknown>
  rest_failures?: Record<string, number>
  rest_responses?: Record<string, unknown>
  public_offers?: Record<
    string,
    {
      status: string
      usable: boolean
      letter_html?: string
      expires_at?: string
      organization?: { name: string; slug?: string }
    }
  >
  public_scheduling?: Record<
    string,
    {
      usable: boolean
      kind: string
      expires_at?: string
      organization?: { name: string; slug?: string }
      application?: { job_title?: string; person_name?: string }
    }
  >
  documents?: Array<{
    id: string
    person_id: string
    filename: string
    content_type: string
    byte_size: number
    scan_status: string
    created_at: string
    downloadable: boolean
    content?: string
    superseded_at?: string
  }>

  upcoming_interview_starts_at?: string
  reject_next_application?: boolean
  application_form?: ApplicationFormPayload
  organization: {
    id: string
    name: string
    slug: string
    careers?: { hero_image_url: string; headline: string; subcopy: string }
  }
  users: Record<string, { id: string; email: string; name: string }>
  people: Array<{
    id: string
    key: string
    display_name: string
    primary_email: string
    primary_phone?: string | null
    lifecycle_stage: string
    visibility: string
    country?: string | null
    region?: string | null
    department: string | null
    location?: string | null
    title?: string | null
    company?: string | null
    years_experience?: number | null
    source?: string | null
    willing_to_relocate?: boolean | null
  }>
  jobs: Array<{
    id: string
    title: string
    status: string
    careers_visibility?: string
    careers_published?: boolean
    openings?: number
    confidential?: boolean
    code_name?: string | null
    dimensions?: Array<{ key: string; label: string; value: string }>
    pipeline_id?: string
    pipeline?: { id: string; stages: Array<{ key: string; name: string; type?: string }> }
  }>
  applications: Array<{
    id: string
    job_id: string
    person_id: string
    status: string
    current_stage_key: string
    pipeline_id?: string
    posting_id?: string
    application_form_snapshot?: PostingQuestion[]
    application_answers?: Record<string, unknown>
  }>
  offers: Array<{
    id: string
    application_id: string
    status: string
    fields?: Record<string, unknown>
  }>
  projects: Array<{
    id: string
    name: string
    job_id?: string | null
    pipeline_id?: string
    confidential?: boolean
    member_count?: number
    pipeline?: { id: string; stages: Array<{ key: string; name: string; type?: string }> }
    job?: { id: string; title: string; status: string } | null
  }>
  project_members: Array<{
    id: string
    project_id: string
    person_id: string
    pipeline_id?: string
    current_stage_key: string
    status: string
    converted_application_id?: string | null
  }>
  interviewer_profiles?: Array<{
    id: string
    user_id: string
    time_zone: string
    working_hours: Record<string, string[][]>
    daily_limit: number
    weekly_limit: number
    buffer_minutes: number
    paused: boolean
  }>
  interviewer_pools?: Array<{
    id: string
    key: string
    name: string
    member_user_ids: string[]
  }>
  calendar_connections?: Array<{
    id: string
    kind: string
    user_id?: string | null
    calendar_id: string
    status: string
  }>
  hiring_teams?: Array<{
    id: string
    job_id: string
    members: Array<{ id: string; user_id: string; team_role: string }>
  }>
  rooms?: Array<{
    id: string
    key: string
    name: string
    resource_email: string
    location_key?: string | null
    capacity: number
  }>
  holidays?: Array<{
    id: string
    name: string
    observed_on: string
    location_key?: string | null
  }>
  expectations: {
    admin_count: number
    recruiter_count: number
    hiring_manager_count: number
    non_user_count: number
    restricted_names: string[]
    hiring_manager_names: string[]
  }
}

const fixturePath = join(dirname(fileURLToPath(import.meta.url)), 'fixtures/bigbuck.json')

export function loadBigBuckFixture(): BigBuckFixture {
  return JSON.parse(readFileSync(fixturePath, 'utf8')) as BigBuckFixture
}

export const MOCK_SESSION_PREFIX = 'bb_sess_mock_'
export const MOCK_CODE_PREFIX = 'bb_hand_mock_'

function mockSession(fixture: BigBuckFixture, user: { id: string; email: string; name: string }) {
  return {
    organization: fixture.organization,
    user,
    membership: { id: `membership-${user.id}`, role_id: 'role' },
    session: {
      token: `${MOCK_SESSION_PREFIX}${user.id}`,
      expires_at: new Date(Date.now() + 3600_000).toISOString(),
    },
  }
}

type MockAgent = {
  id: string
  name: string
  description: string | null
  status: 'active' | 'paused' | 'revoked'
  scopes: string[]
  owner_membership_id: string
  owner_user_id: string
  version: number
  permissions: string[]
}

function publicAgent({ permissions: _p, owner_user_id: _o, ...agent }: MockAgent) {
  return agent
}

const ALL_PERMISSIONS = [
  'person.read',
  'person.read_restricted',
  'document.read',
  'document.upload',
  'person.create',
  'person.update',
  'person.erase',
  'company.manage',
  'sequence.enroll',
  'communication.send',
  'job.read',
  'job.manage',
  'application.read',
  'application.move_stage',
  'project.read',
  'project.manage',
  'sequence.read',
  'sequence.manage',
  'config.plan',
  'webhook.manage',
  'settings.manage',
  'custom_field.manage',
  'agent.manage_own',
  'audit.read',
  'analytics.read',
  'offer.read',
  'offer.create',
  'interview.schedule',
  'scorecard.write',
  'requisition.read',
  'referral.read',
]

export function permissionsForRole(role: string | null): string[] {
  if (role === 'owner') return ALL_PERMISSIONS
  if (role === 'admin') return ALL_PERMISSIONS.filter((permission) => permission !== 'person.erase')
  if (role === 'recruiter') {
    return [
      'person.read',
      'document.read',
      'document.upload',
      'person.create',
      'person.update',
      'company.manage',
      'sequence.enroll',
      'communication.send',
      'job.read',
      'job.manage',
      'application.read',
      'application.move_stage',
      'project.read',
      'project.manage',
      'sequence.read',
      'agent.manage_own',
      'offer.read',
      'interview.schedule',
      'scorecard.write',
      'requisition.read',
      'referral.read',
      'analytics.read',
    ]
  }
  if (role === 'hiring_manager') {
    return [
      'person.read',
      'person.edit_details',
      'document.read',
      'document.upload',
      'job.read',
      'application.read',
      'agent.manage_own',
      'offer.read',
      'scorecard.write',
      'referral.read',
    ]
  }
  return []
}

export function roleForActor(fixture: BigBuckFixture, actorId: string | null): string | null {
  if (!actorId) return null
  for (const [role, user] of Object.entries(fixture.users)) {
    if (user.id === actorId) return role
  }
  return null
}

export function peopleForRole(fixture: BigBuckFixture, role: string | null) {
  if (!role || role === 'non_user') return []
  if (role === 'admin' || role === 'owner') return fixture.people
  if (role === 'recruiter') return fixture.people.filter((p) => p.visibility === 'public')
  if (role === 'hiring_manager') {
    return fixture.people.filter((p) => p.visibility === 'public' && p.department === 'engineering')
  }
  return []
}

function careersConfig(fixture: BigBuckFixture) {
  return (
    fixture.organization.careers ?? {
      hero_image_url: '/careers-canopy.avif',
      headline: 'Open roles',
      subcopy: 'Build with us at Big Buck.',
    }
  )
}

function personById(fixture: BigBuckFixture, id: string) {
  return fixture.people.find((p) => p.id === id)
}

function jobById(fixture: BigBuckFixture, id: string) {
  return fixture.jobs.find((j) => j.id === id)
}

function serializeApplication(fixture: BigBuckFixture, app: BigBuckFixture['applications'][number]) {
  const person = personById(fixture, app.person_id)
  const job = jobById(fixture, app.job_id)
  return {
    id: app.id,
    posting_id: app.posting_id,
    application_form_snapshot: app.application_form_snapshot,
    application_answers: app.application_answers,
    organization_id: fixture.organization.id,
    job_id: app.job_id,
    person_id: app.person_id,
    status: app.status,
    current_stage_key: app.current_stage_key,
    pipeline_id: app.pipeline_id ?? job?.pipeline_id,
    person: person
      ? {
          id: person.id,
          display_name: person.display_name,
          primary_email: person.primary_email,
          primary_phone: person.primary_phone,
          lifecycle_stage: person.lifecycle_stage,
        }
      : null,
    job: job ? { id: job.id, title: job.title, status: job.status } : null,
    pipeline: job?.pipeline ?? null,
    offers: fixture.offers
      .filter((o) => o.application_id === app.id)
      .map((o) => ({ id: o.id, status: o.status })),
  }
}

function projectById(fixture: BigBuckFixture, id: string) {
  return fixture.projects.find((p) => p.id === id)
}

function serializeProjectMember(fixture: BigBuckFixture, member: BigBuckFixture['project_members'][number]) {
  const person = personById(fixture, member.person_id)
  const project = projectById(fixture, member.project_id)
  return {
    id: member.id,
    organization_id: fixture.organization.id,
    project_id: member.project_id,
    person_id: member.person_id,
    pipeline_id: member.pipeline_id ?? project?.pipeline_id,
    current_stage_key: member.current_stage_key,
    status: member.status,
    converted_application_id: member.converted_application_id ?? null,
    person: person
      ? {
          id: person.id,
          display_name: person.display_name,
          primary_email: person.primary_email,
          primary_phone: person.primary_phone,
          lifecycle_stage: person.lifecycle_stage,
        }
      : null,
    project: project ? { id: project.id, name: project.name, job_id: project.job_id ?? null } : null,
    pipeline: project?.pipeline ?? null,
  }
}

function serializeProject(fixture: BigBuckFixture, project: BigBuckFixture['projects'][number]) {
  const job = project.job_id ? jobById(fixture, project.job_id) : null
  const memberCount = fixture.project_members.filter(
    (m) => m.project_id === project.id && m.status === 'active',
  ).length
  return {
    id: project.id,
    organization_id: fixture.organization.id,
    name: project.name,
    job_id: project.job_id ?? null,
    pipeline_id: project.pipeline_id,
    confidential: project.confidential ?? false,
    member_count: memberCount,
    pipeline: project.pipeline ?? null,
    job: job ? { id: job.id, title: job.title, status: job.status } : (project.job ?? null),
  }
}

export async function startMockRailsApi(fixture: BigBuckFixture = loadBigBuckFixture()) {
  let rejectNextApplication = fixture.reject_next_application ?? false
  const submittedScorecards: any[] = []
  const affiliations: any[] = (fixture as any).affiliations ?? []
  const transitions = new Map<string, Array<Record<string, unknown>>>()
  const memberTransitions = new Map<string, Array<Record<string, unknown>>>()
  const mutableApps = [...fixture.applications]
  const bookedInterviews: Array<Record<string, unknown> & { application_id: string }> = []
  const bookingOptions = new Map<string, Record<string, any>>()
  const mutablePeople = [...fixture.people]
  const mutableJobs = [...fixture.jobs]
  const templates: QuestionTemplate[] = []
  const postings: JobPosting[] = []
  const baseline = fixture.application_form ?? {
    required_fields: ['display_name', 'email'],
    standard_fields: ['display_name', 'email', 'phone'],
    screening_questions: [],
  }
  const formFor = (posting: JobPosting) => ({
    ...baseline,
    posting_questions: [
      ...(posting.template_questions ?? []).map((q) => ({ ...q, key: `template.${q.key}` })),
      ...posting.questions.map((q) => ({ ...q, key: `posting.${q.key}` })),
    ],
  })
  const mutableProjects = [...(fixture.projects ?? [])]
  const mutableMembers = [...(fixture.project_members ?? [])]
  const mockAgents: MockAgent[] = []
  const mockCredentials: Array<
    Record<string, unknown> & { id: string; status: string; owner_user_id: string; name: string }
  > = []
  const mockFields: Array<{
    id: string
    entity: string
    key: string
    label: string
    fieldType: string
    dataClass: string
    status: string
    version: number
    required: boolean
    options: Array<{ key: string; label: string }>
  }> = [
    {
      id: 'cf-source',
      entity: 'person',
      key: 'source',
      label: 'Source',
      fieldType: 'text',
      dataClass: 'internal',
      status: 'active',
      version: 1,
      required: false,
      options: [],
    },
  ]
  const liveFixture = () =>
    ({
      ...fixture,
      jobs: mutableJobs,
      people: mutablePeople,
      applications: mutableApps,
      projects: mutableProjects,
      project_members: mutableMembers,
    }) as BigBuckFixture

  const server = http.createServer((req, res) => {
    const url = new URL(req.url ?? '/', 'http://127.0.0.1')
    // Bearer auth like Rails: the token decides org and actor. Tenant headers are ignored.
    const auth = typeof req.headers.authorization === 'string' ? req.headers.authorization : ''
    const bearer = auth.startsWith('Bearer ') ? auth.slice('Bearer '.length) : null
    const actorId = bearer?.startsWith(MOCK_SESSION_PREFIX) ? bearer.slice(MOCK_SESSION_PREFIX.length) : null
    const orgId = actorId ? fixture.organization.id : null

    res.setHeader('Content-Type', 'application/json')
    const failureStatus = req.method === 'GET' ? fixture.rest_failures?.[url.pathname] : undefined
    if (failureStatus) {
      res.statusCode = failureStatus
      res.end(JSON.stringify({ code: 'service_unavailable' }))
      return
    }

    if (
      (url.pathname === '/v1/internal/careers' || url.pathname.startsWith('/v1/public/careers/')) &&
      req.method === 'GET' &&
      !url.pathname.includes('/apply/')
    ) {
      const internal = url.pathname === '/v1/internal/careers'
      if (internal && !actorId) {
        res.statusCode = 401
        res.end(JSON.stringify({ code: 'unauthenticated' }))
        return
      }
      const slug = decodeURIComponent(url.pathname.split('/').pop() ?? '')
      if (!internal && slug !== fixture.organization.slug && slug !== 'big-buck') {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      res.statusCode = 200
      res.end(
        JSON.stringify({
          organization: {
            id: fixture.organization.id,
            name: fixture.organization.name,
            slug: fixture.organization.slug,
          },
          careers: {
            ...careersConfig(fixture),
            about: { title: 'One record. Every surface.', body: 'Same person, same permissions, same API.' },
            culture_intro: null,
            accent_color: '#2ec4b6',
            demo: true,
            culture: [
              { title: 'How we work', body: 'Small teams, clear ownership, and a hiring loop you can see.' },
              {
                title: 'How we hire',
                body: 'A conversation, a work sample, and a decision with the people you would work with.',
              },
            ],
          },
          application_form: baseline,
          jobs: mutableJobs
            .filter((job) => job.status === 'active' && !job.confidential)
            .flatMap((job) => {
              const rows = postings.filter((p) => p.job_id === job.id)
              if (rows.length)
                return rows
                  .filter(
                    (p) =>
                      p.status === 'published' &&
                      [internal ? 'internal' : 'public', 'both'].includes(p.audience),
                  )
                  .map((p) => ({ ...job, title: p.title, posting_id: p.id, application_form: formFor(p) }))
              return job.careers_published !== false &&
                [internal ? 'internal' : 'public', 'both'].includes(job.careers_visibility ?? 'public')
                ? [
                    {
                      ...job,
                      posting_id: `posting-${job.id}`,
                      application_form: { ...baseline, posting_questions: [] },
                      department: job.dimensions?.find((row) => row.key === 'department')?.value ?? null,
                      location: job.dimensions?.find((row) => row.key === 'location')?.value ?? null,
                    },
                  ]
                : []
            }),
        }),
      )
      return
    }

    const publicOffer = url.pathname.match(/^\/v1\/public\/offers\/([^/]+)(\/accept)?$/)
    if (publicOffer) {
      const offer = fixture.public_offers?.[publicOffer[1]!]
      if (!offer) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      if (req.method === 'POST' && publicOffer[2]) {
        if (!offer.usable) {
          res.statusCode = 422
          res.end(JSON.stringify({ code: 'unusable' }))
          return
        }
        offer.status = 'accepted'
        offer.usable = false
        res.end(JSON.stringify({ status: offer.status, hired: false }))
        return
      }
      res.end(JSON.stringify(offer))
      return
    }

    if (url.pathname.startsWith('/v1/public/scheduling/') && req.method === 'GET') {
      res.statusCode = 200
      res.end(
        JSON.stringify({
          id: 'link-1',
          kind: 'self_schedule',
          usable: true,
          application: { id: 'app', job_title: 'Platform Engineer', person_name: 'Ava Chen' },
          ...fixture.public_scheduling?.[url.pathname.split('/').pop()!],
        }),
      )
      return
    }

    if (url.pathname.startsWith('/v1/organizations/') && req.method === 'PATCH') {
      if (!orgId || orgId !== fixture.organization.id) {
        res.statusCode = 401
        res.end(JSON.stringify({ code: 'tenant_required' }))
        return
      }
      res.statusCode = 200
      res.end(
        JSON.stringify({
          id: fixture.organization.id,
          name: fixture.organization.name,
          slug: fixture.organization.slug,
          careers: careersConfig(fixture),
        }),
      )
      return
    }

    const readBody = (cb: (body: any) => void) => {
      const chunks: Buffer[] = []
      req.on('data', (c) => chunks.push(c))
      req.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8')
        cb(raw ? JSON.parse(raw) : {})
      })
    }

    const saveSubmission = (postingId: string, body: any) => {
      const posting = postings.find((p) => p.id === postingId)
      if (!posting) return
      const person = mutablePeople[0]!
      mutableApps.push({
        id: 'app-posting',
        job_id: posting.job_id,
        person_id: person.id,
        status: 'active',
        current_stage_key: 'applied',
        posting_id: posting.id,
        application_form_snapshot: [
          ...baseline.screening_questions,
          ...formFor(posting).posting_questions,
        ] as PostingQuestion[],
        application_answers: body.answers,
      })
    }
    if (url.pathname.startsWith('/v1/internal/careers/apply/') && req.method === 'POST') {
      if (!actorId) {
        res.statusCode = 401
        res.end(JSON.stringify({ code: 'unauthenticated' }))
        return
      }
      readBody((body) => {
        saveSubmission(url.pathname.split('/').pop()!, body)
        res.statusCode = 201
        res.end(JSON.stringify({ application_id: 'app-internal' }))
      })
      return
    }

    const publicApply = url.pathname.match(/^\/v1\/public\/careers\/([^/]+)\/apply\/([^/]+)$/)
    if (publicApply && req.method === 'POST') {
      readBody((body) => {
        if (rejectNextApplication) {
          rejectNextApplication = false
          res.statusCode = 422
          res.end(JSON.stringify({ code: 'invalid_application', title: 'Please retry your application' }))
          return
        }
        saveSubmission(decodeURIComponent(publicApply[2]!), body)
        res.statusCode = 201
        res.end(
          JSON.stringify({
            application_id: 'app-public',
            person_id: 'person-public',
            posting_id: decodeURIComponent(publicApply[2] ?? ''),
          }),
        )
      })
      return
    }

    if (url.pathname === '/v1/sessions/demo_memberships' && req.method === 'GET') {
      const roles = Object.entries(fixture.users)
        .filter(([key]) => key !== 'non_user')
        .map(([key, user]) => ({
          email: user.email,
          name: user.name,
          role_key: key,
          role_name: key === 'hiring_manager' ? 'Hiring manager' : key.charAt(0).toUpperCase() + key.slice(1),
        }))
      res.statusCode = 200
      res.end(JSON.stringify({ data: roles }))
      return
    }

    if (url.pathname === '/v1/sessions' && req.method === 'POST') {
      readBody((body) => {
        const user = Object.values(fixture.users).find(
          (u) => u.email === String(body.email ?? '').toLowerCase(),
        )
        if (!user) {
          res.statusCode = 422
          res.end(JSON.stringify({ code: 'invalid_session', title: 'no_membership' }))
          return
        }
        res.statusCode = 201
        res.end(JSON.stringify(mockSession(fixture, user)))
      })
      return
    }

    if (url.pathname === '/v1/sessions/exchange' && req.method === 'POST') {
      readBody((body) => {
        const code = String(body.code ?? '')
        const user = Object.values(fixture.users).find((u) => `${MOCK_CODE_PREFIX}${u.id}` === code)
        if (!user) {
          res.statusCode = 401
          res.end(JSON.stringify({ code: 'invalid_code' }))
          return
        }
        res.statusCode = 201
        res.end(JSON.stringify(mockSession(fixture, user)))
      })
      return
    }

    if (url.pathname === '/v1/sessions/current' && req.method === 'DELETE') {
      res.statusCode = 204
      res.end()
      return
    }

    if (!orgId || orgId !== fixture.organization.id) {
      res.statusCode = 401
      res.end(JSON.stringify({ code: 'unauthenticated', title: 'Send a bearer token' }))
      return
    }

    if (req.method === 'GET' && fixture.rest_responses && url.pathname in fixture.rest_responses) {
      res.end(JSON.stringify(fixture.rest_responses[url.pathname]))
      return
    }

    const role = roleForActor(fixture, actorId)
    const actingAgentId =
      typeof req.headers['x-bigbuck-act-as-agent'] === 'string' ? req.headers['x-bigbuck-act-as-agent'] : null
    const actingAgent = actingAgentId
      ? mockAgents.find((a) => a.id === actingAgentId && a.status === 'active')
      : null
    const user = Object.values(fixture.users).find((u) => u.id === actorId) ?? null

    const postingList = url.pathname.match(/^\/v1\/jobs\/([^/]+)\/postings$/)
    const postingUpdate = url.pathname.match(/^\/v1\/postings\/([^/]+)$/)
    const templateUpdate = url.pathname.match(/^\/v1\/application_question_templates\/([^/]+)$/)
    if (url.pathname === '/v1/application_question_templates' && req.method === 'GET') {
      res.end(JSON.stringify({ data: templates }))
      return
    }
    if (
      (url.pathname === '/v1/application_question_templates' && req.method === 'POST') ||
      (templateUpdate && req.method === 'PATCH')
    ) {
      readBody((body) => {
        const old = templates.find((t) => t.id === templateUpdate?.[1])
        const row = {
          ...old,
          ...body.question_template,
          id: old?.id ?? `template-${templates.length + 1}`,
          owner_user_id: actorId!,
          owner_name: user?.name ?? '',
          can_edit: true,
          version: (old?.version ?? 0) + 1,
        } as QuestionTemplate
        if (old) Object.assign(old, row)
        else templates.push(row)
        res.statusCode = old ? 200 : 201
        res.end(JSON.stringify(row))
      })
      return
    }
    if (postingList && req.method === 'GET') {
      res.end(
        JSON.stringify({
          data: postings
            .filter((p) => p.job_id === postingList[1])
            .map((p) => ({ ...p, application_form: formFor(p) })),
          application_form: baseline,
        }),
      )
      return
    }
    if ((postingList && req.method === 'POST') || (postingUpdate && req.method === 'PATCH')) {
      readBody((body) => {
        const old = postings.find((p) => p.id === postingUpdate?.[1])
        const row = {
          ...old,
          ...body.posting,
          id: old?.id ?? `posting-new-${postings.length + 1}`,
          job_id: old?.job_id ?? postingList![1],
          version: (old?.version ?? 0) + 1,
        } as JobPosting
        if ('question_template_id' in body.posting) {
          const template = templates.find((t) => t.id === body.posting.question_template_id)
          row.template_questions = structuredClone(template?.questions ?? [])
          row.template_version = template?.version ?? null
        }
        if (old) Object.assign(old, row)
        else postings.push(row)
        res.statusCode = old ? 200 : 201
        res.end(JSON.stringify({ ...row, application_form: formFor(row) }))
      })
      return
    }

    // --- GraphQL (persisted ids or text; the mock dispatches on operationName) ---
    if (url.pathname === '/graphql' && req.method === 'POST') {
      readBody((body) => {
        const op = String(body.operationName ?? '')
        if (fixture.graphql_responses && Object.hasOwn(fixture.graphql_responses, op)) {
          res.end(JSON.stringify(fixture.graphql_responses[op]))
          return
        }
        const vars = (body.variables ?? {}) as Record<string, unknown>
        const permissions = actingAgent ? actingAgent.permissions : permissionsForRole(role)
        const viewer = {
          organizationId: fixture.organization.id,
          actorType: actingAgent ? 'agent' : 'user',
          roleKey: role,
          permissions,
          user: user ? { id: user.id, name: user.name, email: user.email } : null,
          agent: actingAgent ? { id: actingAgent.id, name: actingAgent.name } : null,
        }
        const people = peopleForRole({ ...fixture, people: mutablePeople }, role)
        const personNode = (id: string) => {
          const p = people.find((x) => x.id === id)
          return p ? { id: p.id, displayName: p.display_name, primaryEmail: p.primary_email } : null
        }
        const jobNode = (id: string) => {
          const j = mutableJobs.find((x) => x.id === id)
          return j ? { id: j.id, title: j.title } : null
        }
        let data: Record<string, unknown> | null = null
        if (op === 'Viewer') data = { viewer }
        else if (
          op === 'Today' ||
          op === 'TodayOffers' ||
          op === 'TodayJobs' ||
          op === 'InterviewsHub' ||
          op === 'OffersHub'
        ) {
          const appNode = (applicationId: string) => {
            const app = mutableApps.find((row) => row.id === applicationId)
            if (!app) return null
            return { id: app.id, person: personNode(app.person_id), job: jobNode(app.job_id) }
          }
          const soon =
            fixture.upcoming_interview_starts_at ?? new Date(Date.now() + 36 * 3_600_000).toISOString()
          const past = new Date(Date.now() - 36 * 3_600_000).toISOString()
          const mine = actorId ?? fixture.users.admin.id
          const interviews = [
            {
              id: 'iv-upcoming-ava',
              applicationId: 'app-ava-platform-0001',
              interviewKey: 'recruiter_call',
              status: 'scheduled',
              startsAt: soon,
              interviewerUserIds: [mine],
            },
            {
              id: 'iv-schedule-ben',
              applicationId: 'app-ben-platform-0001',
              interviewKey: 'onsite',
              status: 'needs_attention',
              startsAt: null as string | null,
              interviewerUserIds: [mine],
            },
            {
              id: 'iv-feedback-hana',
              applicationId: 'app-hana-platform-0001',
              interviewKey: 'hm',
              status: 'completed',
              startsAt: past,
              interviewerUserIds: [mine],
            },
            {
              id: 'iv-upcoming-diego',
              applicationId: 'app-diego-platform-0001',
              interviewKey: 'coding',
              status: 'scheduled',
              startsAt: soon,
              interviewerUserIds: ['user-someone-else'],
            },
          ].map((row) => ({ ...row, application: appNode(row.applicationId) }))
          const hubInterview = (row: (typeof interviews)[number]) => ({
            id: row.id,
            applicationId: row.applicationId,
            interviewKey: row.interviewKey,
            status: row.status,
            startsAt: row.startsAt,
            interviewerUserIds: row.interviewerUserIds,
            application: row.application,
          })
          const byTab = {
            upcoming: interviews.filter(
              (row) =>
                row.status === 'scheduled' && row.startsAt && new Date(row.startsAt).getTime() >= Date.now(),
            ),
            schedule: interviews.filter(
              (row) => row.status === 'needs_attention' || row.status === 'requested',
            ),
            feedback: interviews.filter(
              (row) =>
                row.interviewerUserIds.includes(mine) &&
                (row.status === 'scheduled' || row.status === 'completed'),
            ),
            mine: interviews.filter((row) => row.interviewerUserIds.includes(mine)),
          }
          const firstStage = (jobId: string) =>
            mutableJobs.find((job) => job.id === jobId)?.pipeline?.stages?.[0]?.key ?? 'applied'
          const reviews = mutableApps
            .filter((app) => app.status === 'active' && app.current_stage_key === firstStage(app.job_id))
            .map((app) => ({ id: app.id, person: personNode(app.person_id), job: jobNode(app.job_id) }))
          const seededOffers = fixture.offers.map((offer) => ({
            ...offer,
            updatedAt: new Date(Date.now() - 86_400_000).toISOString(),
          }))
          // Older fixtures were drafts only. Add one awaiting-approval row so the
          // Approve tab is not empty when the seed has not covered that status.
          const pendingOffer = seededOffers.some((offer) => offer.status === 'pending_approval')
            ? null
            : {
                id: 'offer-farah-pending-0001',
                application_id: 'app-farah-platform-0001',
                status: 'pending_approval',
                updatedAt: new Date().toISOString(),
              }
          const offerRows = pendingOffer ? [...seededOffers, pendingOffer] : seededOffers
          const statusFilter = typeof vars.status === 'string' ? vars.status : ''
          const counts = [
            'draft',
            'pending_approval',
            'changes_requested',
            'approved',
            'sent',
            'accepted',
            'declined',
            'expired',
            'rescinded',
          ].map((status) => ({
            status,
            count: offerRows.filter((offer) => offer.status === status).length,
          }))
          const offerNode = (offer: (typeof offerRows)[number]) => ({
            id: offer.id,
            status: offer.status,
            updatedAt: offer.updatedAt,
            application: appNode(offer.application_id),
          })
          if (op === 'Today') {
            data = {
              viewer,
              today: {
                feedback: byTab.feedback.map(hubInterview),
                reviews,
                upcoming: byTab.upcoming.map(hubInterview),
              },
            }
          } else if (op === 'TodayOffers') {
            data = {
              today: {
                offersPending: offerRows
                  .filter((offer) => offer.status === 'pending_approval')
                  .map(offerNode),
              },
            }
          } else if (op === 'TodayJobs') {
            data = {
              today: {
                jobs: mutableJobs
                  .filter((job) => job.status === 'active' || job.status === 'open')
                  .map((job) => ({
                    id: job.id,
                    title: job.title,
                    openings: 1,
                    activeCount: mutableApps.filter((app) => app.job_id === job.id && app.status === 'active')
                      .length,
                  })),
              },
            }
          } else if (op === 'InterviewsHub') {
            // Rails narrows upcoming and schedule to the scope; this fixture has no hiring teams, so
            // "mine" means the panels the actor sits on.
            const scoped = (rows: typeof interviews) =>
              vars.scope === 'mine' ? rows.filter((row) => row.interviewerUserIds.includes(mine)) : rows
            data = {
              viewer,
              upcoming: scoped(byTab.upcoming).map(hubInterview),
              schedule: scoped(byTab.schedule).map(hubInterview),
              feedback: byTab.feedback.map(hubInterview),
              mine: byTab.mine.map(hubInterview),
            }
          } else {
            data = {
              offers: {
                counts,
                nodes: offerRows
                  .filter((offer) => !statusFilter || offer.status === statusFilter)
                  .map(offerNode),
              },
            }
          }
        } else if (op === 'JobWorkspace') {
          const job = mutableJobs.find((j) => j.id === vars.id)
          const aged = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString()
          data = {
            job: job
              ? {
                  id: job.id,
                  title: job.title,
                  status: job.status,
                  openings: job.openings ?? 1,
                  confidential: job.confidential ?? false,
                  codeName: job.code_name ?? null,
                  version: 1,
                  stages: (job.pipeline?.stages ?? []).map(
                    (st: { key: string; name?: string; type?: string }) => ({
                      key: st.key,
                      name: st.name ?? null,
                      type: st.type ?? null,
                    }),
                  ),
                  applications: {
                    pageInfo: { hasNextPage: false, endCursor: null },
                    nodes: mutableApps
                      .filter((a) => a.job_id === job.id)
                      .map((a) => ({
                        id: a.id,
                        status: a.status,
                        currentStageKey: a.current_stage_key,
                        version: 1,
                        updatedAt: aged,
                        createdAt: aged,
                        person: personNode(a.person_id),
                        transitions: [],
                      })),
                  },
                }
              : null,
          }
        } else if (op === 'PersonCustomFields') {
          const p = personNode(String(vars.id))
          data = {
            person: p
              ? {
                  id: p.id,
                  customFields: [
                    {
                      key: 'source',
                      fieldType: 'text',
                      fieldVersion: 1,
                      definition: { label: 'Source' },
                      text: 'referral',
                    },
                  ],
                }
              : null,
          }
        } else if (op === 'CustomFieldDefinitions') {
          data = {
            customFieldDefinitions: mockFields
              .filter((f) => f.entity === vars.entity)
              .map(({ entity: _e, ...f }) => f),
          }
        } else if (op === 'CreateCustomField') {
          const field = {
            id: `cf-${mockFields.length + 1}`,
            entity: String(vars.entity),
            key: String(vars.key),
            label: String(vars.label),
            fieldType: String(vars.fieldType),
            dataClass: String(vars.dataClass ?? 'internal'),
            status: 'active',
            version: 1,
            required: false,
            options: (vars.options as Array<{ key: string; label: string }> | undefined) ?? [],
          }
          mockFields.push(field)
          data = {
            createCustomField: { field: { id: field.id, key: field.key, version: 1 }, userErrors: [] },
          }
        } else if (op === 'ArchiveCustomField') {
          const field = mockFields.find((f) => f.id === vars.id)
          if (field) {
            field.status = vars.restore ? 'active' : 'archived'
            field.version += 1
          }
          data = {
            archiveCustomField: {
              field: field ? { id: field.id, status: field.status, version: field.version } : null,
              userErrors: [],
            },
          }
        }
        res.statusCode = data ? 200 : 400
        res.end(JSON.stringify(data ? { data } : { errors: [{ message: `mock does not know ${op}` }] }))
      })
      return
    }

    // --- Agents and credentials ---
    if (url.pathname === '/v1/agents' && req.method === 'GET') {
      res.statusCode = 200
      res.end(
        JSON.stringify({ data: mockAgents.filter((a) => a.owner_user_id === actorId).map(publicAgent) }),
      )
      return
    }
    if (url.pathname === '/v1/agents' && req.method === 'POST') {
      readBody((body) => {
        const agent = {
          id: `agent-${mockAgents.length + 1}`,
          name: String(body.agent?.name ?? ''),
          description: body.agent?.description ?? null,
          status: 'active' as const,
          scopes: (body.agent?.scopes ?? []) as string[],
          owner_membership_id: `membership-${actorId}`,
          owner_user_id: actorId ?? '',
          version: 1,
          permissions: ['person.read', 'job.read', 'application.read'],
        }
        mockAgents.push(agent)
        res.statusCode = 201
        res.end(JSON.stringify(publicAgent(agent)))
      })
      return
    }
    const agentCmd = url.pathname.match(/^\/v1\/agents\/([^/]+)\/(pause|resume|revoke|credentials)$/)
    if (agentCmd && req.method === 'POST') {
      const agent = mockAgents.find((a) => a.id === agentCmd[1] && a.owner_user_id === actorId)
      if (!agent) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      if (agentCmd[2] === 'credentials') {
        const token = `bb_live_mockagent${String(mockCredentials.length).padStart(23, '0')}`
        const cred = {
          id: `cred-${mockCredentials.length + 1}`,
          kind: 'agent' as const,
          name: `${agent.name} token`,
          token_prefix: token.slice(0, 12),
          scopes: [],
          agent_id: agent.id,
          status: 'active',
          owner_user_id: actorId ?? '',
        }
        mockCredentials.push(cred)
        res.statusCode = 201
        res.end(JSON.stringify({ ...cred, token }))
        return
      }
      agent.status = agentCmd[2] === 'pause' ? 'paused' : agentCmd[2] === 'resume' ? 'active' : 'revoked'
      res.statusCode = 200
      res.end(JSON.stringify(publicAgent(agent)))
      return
    }
    if (url.pathname === '/v1/credentials' && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: mockCredentials.filter((c) => c.owner_user_id === actorId) }))
      return
    }
    if (url.pathname === '/v1/credentials' && req.method === 'POST') {
      readBody((body) => {
        const token = `bb_live_mockpersonal${String(mockCredentials.length).padStart(20, '0')}`
        const cred = {
          id: `cred-${mockCredentials.length + 1}`,
          kind: 'personal' as const,
          name: String(body.name ?? ''),
          token_prefix: token.slice(0, 12),
          scopes: body.scopes ?? [],
          agent_id: null,
          status: 'active',
          owner_user_id: actorId ?? '',
        }
        mockCredentials.push(cred)
        res.statusCode = 201
        res.end(JSON.stringify({ ...cred, token }))
      })
      return
    }
    const credRevoke = url.pathname.match(/^\/v1\/credentials\/([^/]+)\/revoke$/)
    if (credRevoke && req.method === 'POST') {
      const cred = mockCredentials.find((c) => c.id === credRevoke[1])
      if (cred) cred.status = 'revoked'
      res.statusCode = cred ? 200 : 404
      res.end(JSON.stringify(cred ?? { code: 'not_found' }))
      return
    }

    const documentPath = url.pathname.match(/^\/v1\/people\/([^/]+)\/documents(?:\/([^/]+))?$/)
    if (documentPath && req.method === 'POST') {
      const role = roleForActor(fixture, actorId)
      const visible = peopleForRole({ ...fixture, people: mutablePeople }, role).some(
        (person) => person.id === documentPath[1],
      )
      if (!permissionsForRole(role).includes('document.upload') || !visible) {
        res.statusCode = visible ? 403 : 404
        res.end(JSON.stringify({ code: 'forbidden' }))
        return
      }
      const chunks: Buffer[] = []
      req.on('data', (chunk) => chunks.push(chunk))
      req.on('end', async () => {
        const form = await new Request('http://mock/resume', {
          method: 'POST',
          headers: { 'Content-Type': req.headers['content-type']! },
          body: Buffer.concat(chunks),
        }).formData()
        const file = form.get('file') as File
        const documents = (fixture.documents ??= [])
        documents
          .filter((doc) => doc.person_id === documentPath[1])
          .forEach((doc) => {
            doc.superseded_at = new Date().toISOString()
          })
        const doc = {
          id: `replacement-${documents.length}`,
          person_id: documentPath[1]!,
          filename: file.name,
          content_type: file.type,
          byte_size: file.size,
          scan_status: 'pending',
          created_at: new Date().toISOString(),
          downloadable: false,
          content: await file.text(),
        }
        documents.push(doc)
        res.statusCode = 201
        res.end(JSON.stringify(doc))
      })
      return
    }
    if (documentPath && req.method === 'GET') {
      const role = roleForActor(fixture, actorId)
      const visible = peopleForRole({ ...fixture, people: mutablePeople }, role).some(
        (person) => person.id === documentPath[1],
      )
      if (!permissionsForRole(role).includes('document.read') || !visible) {
        res.statusCode = visible ? 403 : 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      const documents = (fixture.documents ?? []).filter(
        (document) =>
          document.person_id === documentPath[1] && (Boolean(documentPath[2]) || !document.superseded_at),
      )
      if (!documentPath[2]) {
        res.end(
          JSON.stringify({
            data: documents.map(({ content: _content, person_id: _person, ...document }) => document),
          }),
        )
        return
      }
      const document = documents.find((document) => document.id === documentPath[2])
      if (!document?.downloadable || document.scan_status !== 'clean') {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      res.setHeader('Content-Type', document.content_type)
      res.setHeader(
        'Content-Disposition',
        `${url.searchParams.get('download') === 'true' ? 'attachment' : 'inline'}; filename="${document.filename}"`,
      )
      res.end(document.content ?? '%PDF-1.4 test resume')
      return
    }

    if (url.pathname === '/v1/people' && req.method === 'GET') {
      const role = roleForActor(fixture, actorId)
      const visibleIds = new Set(peopleForRole({ ...fixture, people: mutablePeople }, role).map((p) => p.id))
      const q = (url.searchParams.get('q') ?? '').toLowerCase()
      const lifecycle = url.searchParams.get('lifecycle_stage') ?? ''
      const projectId = url.searchParams.get('project_id') ?? ''
      const poolIds = projectId
        ? new Set(
            fixture.project_members
              .filter((member) => member.project_id === projectId)
              .map((member) => member.person_id),
          )
        : null
      const data = mutablePeople
        .filter((p) => visibleIds.has(p.id))
        .filter((p) => !lifecycle || p.lifecycle_stage === lifecycle)
        .filter((p) => !poolIds || poolIds.has(p.id))
        .filter(
          (p) =>
            !q ||
            p.display_name.toLowerCase().includes(q) ||
            (p.primary_email ?? '').toLowerCase().includes(q),
        )
        .map((p) => ({
          id: p.id,
          organization_id: fixture.organization.id,
          display_name: p.display_name,
          primary_email: p.primary_email,
          primary_phone: p.primary_phone ?? null,
          lifecycle_stage: p.lifecycle_stage,
          visibility: p.visibility,
          country: p.country ?? null,
          region: p.region ?? null,
        }))
      res.statusCode = 200
      res.end(JSON.stringify({ data }))
      return
    }

    if (url.pathname === '/v1/people' && req.method === 'POST') {
      readBody((body) => {
        const person = {
          id: `person-new-${mutablePeople.length + 1}`,
          key: `new-${mutablePeople.length + 1}`,
          display_name: body.person?.display_name ?? 'Unnamed',
          primary_email: body.person?.email ?? '',
          lifecycle_stage: 'prospect',
          visibility: 'public',
          department: null,
        }
        mutablePeople.push(person)
        res.statusCode = 201
        res.end(
          JSON.stringify({
            id: person.id,
            display_name: person.display_name,
            primary_email: person.primary_email,
            lifecycle_stage: person.lifecycle_stage,
            visibility: person.visibility,
          }),
        )
      })
      return
    }

    const personShow = url.pathname.match(/^\/v1\/people\/([^/]+)$/)
    if (personShow && req.method === 'PATCH') {
      const role = roleForActor(fixture, actorId)
      const person = peopleForRole({ ...fixture, people: mutablePeople }, role).find(
        (row) => row.id === personShow[1],
      )
      if (
        !person ||
        !permissionsForRole(role).some((permission) =>
          ['person.update', 'person.edit_details'].includes(permission),
        )
      ) {
        res.statusCode = person ? 403 : 404
        res.end(JSON.stringify({ code: 'forbidden' }))
        return
      }
      readBody((body) => {
        const edits = body.person
        if ('display_name' in edits) person.display_name = edits.display_name
        if ('email' in edits) person.primary_email = edits.email.trim().toLowerCase()
        if ('phone' in edits) person.primary_phone = edits.phone
        if (edits.affiliation) {
          let row = affiliations.find((row) => row.id === edits.affiliation.id && row.person_id === person.id)
          if (!row) {
            row = { id: `aff-${affiliations.length}`, person_id: person.id, current: true }
            affiliations.push(row)
          }
          Object.assign(row, {
            company_id: edits.affiliation.company_id,
            title: edits.affiliation.title,
            company: (fixture as any).companies?.find(
              (company: any) => company.id === edits.affiliation.company_id,
            ),
          })
        }
        res.statusCode = 200
        res.end(JSON.stringify(person))
      })
      return
    }
    if (personShow && req.method === 'GET') {
      const id = personShow[1]
      const role = roleForActor(fixture, actorId)
      const person = peopleForRole({ ...fixture, people: mutablePeople }, role).find((p) => p.id === id)
      if (!person) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      res.statusCode = 200
      res.end(
        JSON.stringify({
          id: person.id,
          organization_id: fixture.organization.id,
          display_name: person.display_name,
          primary_email: person.primary_email,
          primary_phone: person.primary_phone,
          lifecycle_stage: person.lifecycle_stage,
          visibility: person.visibility,
        }),
      )
      return
    }

    if (url.pathname === '/v1/jobs' && req.method === 'GET') {
      const role = roleForActor(fixture, actorId)
      if (!role || role === 'non_user') {
        res.statusCode = 200
        res.end(JSON.stringify({ data: [] }))
        return
      }
      res.statusCode = 200
      res.end(JSON.stringify({ data: mutableJobs }))
      return
    }

    if (url.pathname === '/v1/jobs' && req.method === 'POST') {
      readBody((body) => {
        const stages = [
          { key: 'applied', name: 'Applied', type: 'apply' },
          { key: 'onsite', name: 'Onsite', type: 'interview' },
          { key: 'offer', name: 'Offer', type: 'offer' },
        ]
        const job = {
          id: `job-new-${mutableJobs.length + 1}`,
          title: body.job?.title ?? 'Untitled',
          status: body.job?.status ?? 'active',
          pipeline_id: `pipe-new-${mutableJobs.length + 1}`,
          pipeline: { id: `pipe-new-${mutableJobs.length + 1}`, stages },
        }
        mutableJobs.push(job)
        res.statusCode = 201
        res.end(JSON.stringify(job))
      })
      return
    }

    const jobShow = url.pathname.match(/^\/v1\/jobs\/([^/]+)$/)
    if (jobShow && req.method === 'PATCH') {
      const job = mutableJobs.find((j) => j.id === jobShow[1])
      if (!job) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      readBody((body) => {
        if (body.job?.openings != null) job.openings = Number(body.job.openings)
        if (body.job?.careers_visibility) job.careers_visibility = String(body.job.careers_visibility)
        if (typeof body.job?.careers_published === 'boolean')
          job.careers_published = body.job.careers_published
        res.statusCode = 200
        res.end(JSON.stringify({ ...job, openings: job.openings ?? 1 }))
      })
      return
    }
    if (jobShow && req.method === 'GET') {
      const job = mutableJobs.find((j) => j.id === jobShow[1])
      if (!job) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      const team = (fixture.hiring_teams ?? []).find((row) => row.job_id === job.id)
      const hiringTeam = (team?.members ?? []).map((member) => ({
        user_id: member.user_id,
        name: Object.values(fixture.users).find((user) => user.id === member.user_id)?.name ?? null,
        email: Object.values(fixture.users).find((user) => user.id === member.user_id)?.email ?? null,
        role: member.team_role,
      }))
      res.statusCode = 200
      res.end(
        JSON.stringify({
          ...job,
          openings: job.openings ?? 1,
          confidential: job.confidential ?? false,
          code_name: job.code_name ?? null,
          dimensions: job.dimensions ?? [],
          hiring_team: hiringTeam,
        }),
      )
      return
    }

    if (url.pathname === '/v1/applications' && req.method === 'GET') {
      const jobId = url.searchParams.get('job_id')
      const personId = url.searchParams.get('person_id')
      const stage = url.searchParams.get('stage')
      let data = mutableApps
      if (jobId) data = data.filter((a) => a.job_id === jobId)
      if (personId) data = data.filter((a) => a.person_id === personId)
      if (stage) data = data.filter((a) => a.current_stage_key === stage)
      const total = data.length
      const page = Math.max(1, Number(url.searchParams.get('page') ?? '1') || 1)
      const per = Math.max(
        1,
        Number(url.searchParams.get('per_page') ?? (url.searchParams.get('page') ? '25' : '100')) || 100,
      )
      const slice = data.slice((page - 1) * per, page * per)
      res.statusCode = 200
      res.end(
        JSON.stringify({
          data: slice.map((a) =>
            serializeApplication(
              { ...fixture, jobs: mutableJobs, people: mutablePeople, applications: mutableApps },
              a,
            ),
          ),
          meta: { page, per_page: per, total },
        }),
      )
      return
    }

    const transitionMatch = url.pathname.match(/^\/v1\/applications\/([^/]+)\/transitions$/)
    if (transitionMatch) {
      const appId = transitionMatch[1]
      const app = mutableApps.find((a) => a.id === appId)
      if (!app) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      if (req.method === 'GET') {
        res.statusCode = 200
        res.end(JSON.stringify({ data: transitions.get(appId) ?? [] }))
        return
      }
      if (req.method === 'POST') {
        readBody((body) => {
          const command = body.command ?? 'move'
          const from = app.current_stage_key
          if (command === 'move') {
            app.current_stage_key = body.to_stage_key
          } else if (command === 'reject') {
            app.status = 'rejected'
          } else if (command === 'withdraw') {
            app.status = 'withdrawn'
          } else if (command === 'hire') {
            app.status = 'hired'
          }
          const row = {
            id: `tr-${Date.now()}`,
            from_stage_key: from,
            to_stage_key: body.to_stage_key ?? from,
            command,
            reason: body.reason ?? null,
          }
          const list = transitions.get(appId) ?? []
          list.push(row)
          transitions.set(appId, list)
          res.statusCode = 201
          res.end(
            JSON.stringify(
              serializeApplication(
                { ...fixture, jobs: mutableJobs, people: mutablePeople, applications: mutableApps },
                app,
              ),
            ),
          )
        })
        return
      }
    }

    const bookingPath = url.pathname.match(/^\/v1\/applications\/([^/]+)\/(booking_options|bookings)$/)
    if (bookingPath && req.method === 'POST') {
      readBody((body) => {
        if (bookingPath[2] === 'booking_options') {
          const options = [0, 1, 2].map((index) => {
            const start = new Date(body.search_start)
            start.setUTCHours(14 + index, 0, 0, 0)
            const end = new Date(start.getTime() + body.interview_defs[0].duration_minutes * 60_000)
            const token = `booking-option-${bookingOptions.size + 1}`
            const option = {
              token,
              starts_at: start.toISOString(),
              ends_at: end.toISOString(),
              blocks: [
                {
                  interview_key: body.interview_defs[0].key,
                  starts_at: start.toISOString(),
                  ends_at: end.toISOString(),
                  user_ids: body.interview_defs[0].candidate_user_ids,
                },
              ],
            }
            bookingOptions.set(token, { ...option, application_id: bookingPath[1] })
            return option
          })
          res.statusCode = 200
          res.end(JSON.stringify({ options }))
        } else {
          const option = bookingOptions.get(body.booking_token)
          if (!option || option.application_id !== bookingPath[1]) {
            res.statusCode = 422
            res.end(JSON.stringify({ title: 'proposal_expired' }))
            return
          }
          bookingOptions.delete(body.booking_token)
          const app = mutableApps.find((row) => row.id === bookingPath[1])!
          const interview = {
            id: `interview-${bookedInterviews.length + 1}`,
            application_id: app.id,
            stage_key: app.current_stage_key,
            interview_key: option.blocks[0].interview_key,
            status: 'scheduled',
            starts_at: option.starts_at,
            ends_at: option.ends_at,
            interviewer_user_ids: option.blocks[0].user_ids,
          }
          bookedInterviews.push(interview)
          res.statusCode = 201
          res.end(JSON.stringify({ booked: true, interviews: [interview] }))
        }
      })
      return
    }

    const appInterviewsEarly = url.pathname.match(/^\/v1\/applications\/([^/]+)\/interviews$/)
    if (appInterviewsEarly && req.method === 'GET') {
      res.statusCode = 200
      res.end(
        JSON.stringify({
          data: bookedInterviews.filter((row) => row.application_id === appInterviewsEarly[1]),
        }),
      )
      return
    }

    const interviewShow = url.pathname.match(/^\/v1\/interviews\/([^/]+)$/)
    if (interviewShow && req.method === 'GET') {
      const interview = bookedInterviews.find((row) => row.id === interviewShow[1])
      if (!interview) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found', title: 'Interview not found' }))
        return
      }
      res.statusCode = 200
      res.end(JSON.stringify(interview))
      return
    }

    const appShow = url.pathname.match(/^\/v1\/applications\/([^/]+)$/)
    if (appShow && req.method === 'GET') {
      const id = appShow[1]
      const app = mutableApps.find((a) => a.id === id)
      if (!app) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      res.statusCode = 200
      res.end(
        JSON.stringify(
          serializeApplication(
            { ...fixture, jobs: mutableJobs, people: mutablePeople, applications: mutableApps },
            app,
          ),
        ),
      )
      return
    }

    if (url.pathname === '/v1/offers' && req.method === 'GET') {
      const applicationId = url.searchParams.get('application_id')
      let data = fixture.offers
      if (applicationId) data = data.filter((o) => o.application_id === applicationId)
      res.statusCode = 200
      res.end(
        JSON.stringify({
          data: data.map((o) => ({
            id: o.id,
            application_id: o.application_id,
            status: o.status,
            fields: o.fields ?? null,
          })),
        }),
      )
      return
    }

    if (url.pathname.startsWith('/v1/offers/') && req.method === 'GET') {
      const id = url.pathname.split('/').pop()
      const offer =
        fixture.offers.find((o) => o.id === id) ??
        (id === 'offer-farah-pending-0001'
          ? {
              id,
              application_id: 'app-farah-platform-0001',
              status: 'pending_approval',
              fields: { currency: 'USD', base_salary: 145000 },
            }
          : undefined)
      if (!offer) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      const app = mutableApps.find((a) => a.id === offer.application_id)
      res.statusCode = 200
      res.end(
        JSON.stringify({
          id: offer.id,
          application_id: offer.application_id,
          status: offer.status,
          fields: offer.fields ?? null,
          application: app
            ? {
                id: app.id,
                job_id: app.job_id,
                person_id: app.person_id,
                status: app.status,
                current_stage_key: app.current_stage_key,
              }
            : null,
        }),
      )
      return
    }

    const offerAction = url.pathname.match(/^\/v1\/offers\/([^/]+)\/(submit|approve|send|rescind)$/)
    if (offerAction && req.method === 'POST') {
      const offer = fixture.offers.find((o) => o.id === offerAction[1])
      if (!offer) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      const action = offerAction[2]
      if (action === 'submit') offer.status = 'approved'
      if (action === 'approve') offer.status = 'approved'
      if (action === 'send') offer.status = 'sent'
      if (action === 'rescind') offer.status = 'rescinded'
      res.statusCode = 200
      res.end(
        JSON.stringify({
          id: offer.id,
          application_id: offer.application_id,
          status: offer.status,
          fields: offer.fields ?? null,
          send: action === 'send' ? { token: 'mock-send-token' } : undefined,
        }),
      )
      return
    }

    if (url.pathname === '/v1/projects' && req.method === 'GET') {
      const role = roleForActor(fixture, actorId)
      if (!role || role === 'non_user') {
        res.statusCode = 200
        res.end(JSON.stringify({ data: [] }))
        return
      }
      res.statusCode = 200
      res.end(
        JSON.stringify({
          data: mutableProjects.map((p) => serializeProject(liveFixture(), p)),
        }),
      )
      return
    }

    if (url.pathname === '/v1/projects' && req.method === 'POST') {
      readBody((body) => {
        const stages = [
          { key: 'prospect', name: 'Prospect', type: 'source' },
          { key: 'reached-out', name: 'Reached out', type: 'outreach' },
          { key: 'replied', name: 'Replied', type: 'outreach' },
          { key: 'ready', name: 'Ready', type: 'ready' },
        ]
        const jobId = body.project?.job_id ?? null
        const job = jobId ? jobById(liveFixture(), jobId) : null
        const project = {
          id: `project-new-${mutableProjects.length + 1}`,
          name: body.project?.name ?? 'Untitled pool',
          job_id: jobId,
          pipeline_id: `pipe-project-new-${mutableProjects.length + 1}`,
          confidential: false,
          pipeline: { id: `pipe-project-new-${mutableProjects.length + 1}`, stages },
          job: job ? { id: job.id, title: job.title, status: job.status } : null,
        }
        mutableProjects.push(project)
        res.statusCode = 201
        res.end(JSON.stringify(serializeProject(liveFixture(), project)))
      })
      return
    }

    const poolPeople = url.pathname.match(/^\/v1\/projects\/([^/]+)\/people$/)
    if (poolPeople && req.method === 'POST') {
      readBody((body) => {
        const ids: string[] = body.person_ids ?? []
        res.statusCode = 200
        res.end(JSON.stringify({ added: ids.length, already_members: 0 }))
      })
      return
    }

    const projectMembers = url.pathname.match(/^\/v1\/projects\/([^/]+)\/members$/)
    if (projectMembers) {
      const projectId = projectMembers[1]
      const project = mutableProjects.find((p) => p.id === projectId)
      if (!project) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      if (req.method === 'GET') {
        const rows = mutableMembers.filter((m) => m.project_id === projectId)
        res.statusCode = 200
        res.end(
          JSON.stringify({
            data: rows.map((m) => serializeProjectMember(liveFixture(), m)),
          }),
        )
        return
      }
      if (req.method === 'POST') {
        readBody((body) => {
          const personId = body.member?.person_id
          const existing = mutableMembers.find((m) => m.project_id === projectId && m.person_id === personId)
          if (existing) {
            res.statusCode = 422
            res.end(JSON.stringify({ code: 'already_a_member' }))
            return
          }
          const member = {
            id: `pm-new-${mutableMembers.length + 1}`,
            project_id: projectId,
            person_id: personId,
            pipeline_id: project.pipeline_id,
            current_stage_key: project.pipeline?.stages?.[0]?.key ?? 'prospect',
            status: 'active',
            converted_application_id: null,
          }
          mutableMembers.push(member)
          res.statusCode = 201
          res.end(JSON.stringify(serializeProjectMember(liveFixture(), member)))
        })
        return
      }
    }

    const projectShow = url.pathname.match(/^\/v1\/projects\/([^/]+)$/)
    if (projectShow && req.method === 'GET') {
      const project = mutableProjects.find((p) => p.id === projectShow[1])
      if (!project) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      res.statusCode = 200
      res.end(JSON.stringify(serializeProject(liveFixture(), project)))
      return
    }

    if (url.pathname === '/v1/project_members' && req.method === 'GET') {
      const personId = url.searchParams.get('person_id')
      const projectId = url.searchParams.get('project_id')
      let rows = mutableMembers
      if (personId) rows = rows.filter((m) => m.person_id === personId)
      if (projectId) rows = rows.filter((m) => m.project_id === projectId)
      res.statusCode = 200
      res.end(
        JSON.stringify({
          data: rows.map((m) => serializeProjectMember(liveFixture(), m)),
        }),
      )
      return
    }

    const memberTransition = url.pathname.match(/^\/v1\/project_members\/([^/]+)\/transitions$/)
    if (memberTransition) {
      const memberId = memberTransition[1]
      const member = mutableMembers.find((m) => m.id === memberId)
      if (!member) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      if (req.method === 'GET') {
        res.statusCode = 200
        res.end(JSON.stringify({ data: memberTransitions.get(memberId) ?? [] }))
        return
      }
      if (req.method === 'POST') {
        readBody((body) => {
          const command = body.command ?? 'move'
          const from = member.current_stage_key
          if (command === 'move') {
            member.current_stage_key = body.to_stage_key
          } else if (command === 'reject') {
            member.status = 'rejected'
          } else if (command === 'withdraw') {
            member.status = 'withdrawn'
          }
          const row = {
            id: `mtr-${Date.now()}`,
            from_stage_key: from,
            to_stage_key: body.to_stage_key ?? from,
            command,
            reason: body.reason ?? null,
          }
          const list = memberTransitions.get(memberId) ?? []
          list.push(row)
          memberTransitions.set(memberId, list)
          res.statusCode = 201
          res.end(JSON.stringify(serializeProjectMember(liveFixture(), member)))
        })
        return
      }
    }

    const poolBulkMove = url.pathname.match(/^\/v1\/projects\/([^/]+)\/transitions$/)
    if (poolBulkMove && req.method === 'POST') {
      readBody((body) => {
        const wanted = new Set<string>(body.member_ids ?? [])
        const rows = mutableMembers.filter(
          (m) => m.project_id === poolBulkMove[1] && m.status === 'active' && wanted.has(m.id),
        )
        for (const member of rows) member.current_stage_key = body.to_stage_key
        res.statusCode = 200
        res.end(JSON.stringify({ moved: rows.length }))
      })
      return
    }

    const memberConvert = url.pathname.match(/^\/v1\/project_members\/([^/]+)\/convert$/)
    if (memberConvert && req.method === 'POST') {
      readBody((body) => {
        const member = mutableMembers.find((m) => m.id === memberConvert[1])
        if (!member) {
          res.statusCode = 404
          res.end(JSON.stringify({ code: 'not_found' }))
          return
        }
        const project = projectById(liveFixture(), member.project_id)
        const jobId = body.job_id ?? project?.job_id
        if (!jobId) {
          res.statusCode = 422
          res.end(JSON.stringify({ code: 'job_required' }))
          return
        }
        const app = {
          id: `app-from-pool-${mutableApps.length + 1}`,
          job_id: jobId,
          person_id: member.person_id,
          status: 'active',
          current_stage_key: 'applied',
          pipeline_id: jobById(liveFixture(), jobId)?.pipeline_id,
        }
        mutableApps.push(app)
        member.status = 'converted'
        member.converted_application_id = app.id
        res.statusCode = 201
        res.end(
          JSON.stringify({
            member: serializeProjectMember(liveFixture(), member),
            application: serializeApplication(liveFixture(), app),
          }),
        )
      })
      return
    }

    const memberShow = url.pathname.match(/^\/v1\/project_members\/([^/]+)$/)
    if (memberShow && req.method === 'GET') {
      const member = mutableMembers.find((m) => m.id === memberShow[1])
      if (!member) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      res.statusCode = 200
      res.end(JSON.stringify(serializeProjectMember(liveFixture(), member)))
      return
    }

    const personTimeline = url.pathname.match(/^\/v1\/people\/([^/]+)\/timeline$/)
    if (personTimeline && req.method === 'GET') {
      res.statusCode = 200
      res.end(
        JSON.stringify({
          data: [
            {
              id: 'evt-1',
              person_id: personTimeline[1],
              event_type: 'communication.sent',
              occurred_at: '2026-10-25T12:00:00Z',
            },
          ],
        }),
      )
      return
    }

    const personComm = url.pathname.match(/^\/v1\/people\/([^/]+)\/communications$/)
    if (personComm && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: [] }))
      return
    }
    if (personComm && req.method === 'POST') {
      readBody((body) => {
        res.statusCode = 201
        res.end(
          JSON.stringify({
            id: 'comm-1',
            person_id: personComm[1],
            status: 'sent',
            subject: body.subject,
          }),
        )
      })
      return
    }

    const appOffers = url.pathname.match(/^\/v1\/applications\/([^/]+)\/offers$/)
    if (appOffers && req.method === 'POST') {
      readBody((body) => {
        const offer = {
          id: `offer-new-${fixture.offers.length + 1}`,
          application_id: appOffers[1],
          status: 'draft',
          fields: body.offer?.fields ?? {},
        }
        fixture.offers.push(offer)
        const app = mutableApps.find((a) => a.id === appOffers[1])
        // keep fixture offers in sync for application serialize
        void app
        res.statusCode = 201
        res.end(JSON.stringify(offer))
      })
      return
    }

    const appSched = url.pathname.match(/^\/v1\/applications\/([^/]+)\/scheduling_links$/)
    if (appSched && req.method === 'POST') {
      res.statusCode = 201
      res.end(
        JSON.stringify({
          id: 'link-1',
          application_id: appSched[1],
          kind: 'self_schedule',
          interview_keys: ['screen'],
          token: 'mock-scheduling-token',
        }),
      )
      return
    }

    // Kept on the fixture so a sequence created in one request is there for the next.
    const sequences = ((fixture as any).sequences ??= [
      {
        id: 'seq-default-0001',
        key: 'default-outreach',
        name: 'Default outreach',
        status: 'active',
        steps: [{ id: 's-default-1', type: 'email', template_key: 'outreach-1' }],
        enrollment_count: 0,
      },
    ])
    const enrollments = ((fixture as any).enrollments ??= [])
    const mailboxes = (fixture as any).mailboxes ?? [
      { id: 'mb-shared-0001', kind: 'shared', email: 'recruiting@bigbuck.test', status: 'connected' },
      {
        id: 'mb-recruiter-0001',
        kind: 'personal',
        email: 'recruiter@bigbuck.test',
        user_id: fixture.users.recruiter?.id ?? 'user-recruiter-0001',
        status: 'connected',
      },
    ]
    const companies = (fixture as any).companies ?? [
      {
        id: 'co-example-0001',
        name: 'Example Systems',
        domain: 'example.com',
        industry: 'Software',
        employee_band: '51-200',
        affiliation_count: 1,
        current_count: 1,
        former_count: 0,
      },
    ]
    const webhooks = (fixture as any).webhooks ?? []

    if (url.pathname === '/v1/agent_proposals' && req.method === 'GET') {
      const all = ((fixture as any).agent_proposals ?? []) as Array<{ status: string }>
      const status = url.searchParams.get('status')
      const statuses: Record<string, number> = {}
      for (const row of all) statuses[row.status] = (statuses[row.status] ?? 0) + 1
      res.statusCode = 200
      res.end(
        JSON.stringify({
          data: status ? all.filter((row) => row.status === status) : all,
          meta: { statuses },
        }),
      )
      return
    }
    if (url.pathname === '/v1/sequences' && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: sequences }))
      return
    }
    if (url.pathname === '/v1/sequences' && req.method === 'POST') {
      readBody((body) => {
        const sequence = {
          id: `seq-new-${sequences.length + 1}`,
          key: body.sequence?.key ?? 'new',
          name: body.sequence?.name ?? 'New',
          status: 'active',
          // Like SequencesController#default_steps: a sequence created without steps starts with one email
          // from the first template, because Rails requires at least one step.
          steps: (body.sequence?.steps?.length ? body.sequence.steps : null) ?? [
            { id: `s-mock-default-${sequences.length + 1}`, type: 'email', template_key: 'outreach-1' },
          ],
          enrollment_count: 0,
        }
        sequences.push(sequence)
        res.statusCode = 201
        res.end(JSON.stringify(sequence))
      })
      return
    }
    const seqShow = url.pathname.match(/^\/v1\/sequences\/([^/]+)$/)
    if (seqShow && (req.method === 'GET' || req.method === 'PATCH')) {
      const sequence = sequences.find((s: any) => s.id === seqShow[1])
      if (!sequence) {
        res.statusCode = 404
        res.end(JSON.stringify({ code: 'not_found' }))
        return
      }
      if (req.method === 'GET') {
        res.statusCode = 200
        res.end(JSON.stringify(sequence))
        return
      }
      readBody((body) => {
        // Sequence validates :steps, presence: true.
        if (Array.isArray(body.sequence?.steps) && body.sequence.steps.length === 0) {
          res.statusCode = 422
          res.end(JSON.stringify({ code: 'validation_failed', message: 'Validation failed' }))
          return
        }
        // Like SequenceSteps.normalize: every stored step has an id.
        if (Array.isArray(body.sequence?.steps)) {
          sequence.steps = body.sequence.steps.map((step: any, index: number) => ({
            ...step,
            id: step.id ?? `s-mock-${Date.now().toString(36)}-${index}`,
          }))
        }
        res.statusCode = 200
        res.end(JSON.stringify(sequence))
      })
      return
    }
    // Enrollment review: who would be enrolled and who is skipped, with the reason Rails would give.
    const seqPlan = url.pathname.match(/^\/v1\/sequences\/([^/]+)\/(enrollment_plan|enroll_planned)$/)
    if (seqPlan && req.method === 'POST') {
      readBody((body) => {
        const ids: string[] = body.person_ids
          ? body.person_ids
          : body.project_id
            ? mutableMembers.filter((m) => m.project_id === body.project_id).map((m) => m.person_id)
            : []
        const people = ids.map((id) => personById(fixture, id)).filter(Boolean) as any[]
        const reason = (person: any) =>
          !person.primary_email
            ? 'no_email'
            : person.do_not_contact
              ? 'do_not_contact'
              : enrollments.some((e: any) => e.person_id === person.id && e.status === 'active')
                ? 'active_enrollment'
                : null
        const row = (person: any) => ({
          id: person.id,
          display_name: person.display_name,
          primary_email: person.primary_email ?? null,
        })
        const eligible = people.filter((person) => !reason(person))
        res.statusCode = 200
        if (seqPlan[2] === 'enrollment_plan') {
          res.end(
            JSON.stringify({
              sequence_id: seqPlan[1],
              will_enroll: eligible.map(row),
              skipped: people
                .filter((person) => reason(person))
                .map((person) => ({ ...row(person), reason: reason(person) })),
              first_send_at: null,
            }),
          )
          return
        }
        for (const person of eligible) {
          enrollments.push({
            id: `enr-${enrollments.length + 1}`,
            sequence_id: seqPlan[1],
            person_id: person.id,
            mailbox_id: body.mailbox_id ?? mailboxes[0]?.id,
            step_index: 1,
            status: 'active',
            stop_reason: null,
            sequence: sequences.find((s: any) => s.id === seqPlan[1]) ?? null,
            person,
          })
        }
        res.end(
          JSON.stringify({ enrolled: eligible.length, failed: 0, skipped: people.length - eligible.length }),
        )
      })
      return
    }
    const seqEnroll = url.pathname.match(/^\/v1\/sequences\/([^/]+)\/enrollments$/)
    if (seqEnroll && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: enrollments.filter((e: any) => e.sequence_id === seqEnroll[1]) }))
      return
    }
    if (seqEnroll && req.method === 'POST') {
      readBody((body) => {
        const enrollment = {
          id: `enr-${enrollments.length + 1}`,
          sequence_id: seqEnroll[1],
          person_id: body.enrollment?.person_id,
          mailbox_id: body.enrollment?.mailbox_id ?? mailboxes[0]?.id,
          step_index: 1,
          status: 'active',
          stop_reason: null,
          sequence: sequences.find((s: any) => s.id === seqEnroll[1]) ?? null,
          person: personById(fixture, body.enrollment?.person_id) ?? null,
        }
        enrollments.push(enrollment)
        res.statusCode = 201
        res.end(JSON.stringify(enrollment))
      })
      return
    }
    if (url.pathname === '/v1/enrollments' && req.method === 'GET') {
      const personId = url.searchParams.get('person_id')
      let rows = enrollments
      if (personId) rows = rows.filter((e: any) => e.person_id === personId)
      res.statusCode = 200
      res.end(JSON.stringify({ data: rows }))
      return
    }
    if (url.pathname === '/v1/mailboxes' && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: mailboxes }))
      return
    }
    if (url.pathname === '/v1/companies' && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: companies }))
      return
    }
    const companyShow = url.pathname.match(/^\/v1\/companies\/([^/]+)$/)
    if (companyShow && req.method === 'GET') {
      const company = companies.find((row: { id: string }) => row.id === companyShow[1])
      res.statusCode = company ? 200 : 404
      res.end(JSON.stringify(company ?? { code: 'not_found' }))
      return
    }
    if (url.pathname === '/v1/companies' && req.method === 'POST') {
      readBody((body) => {
        const company = {
          id: `co-new-${companies.length + 1}`,
          name: body.company?.name ?? 'Company',
          domain: body.company?.domain ?? null,
          affiliation_count: 0,
        }
        companies.push(company)
        res.statusCode = 201
        res.end(JSON.stringify(company))
      })
      return
    }
    if (url.pathname === '/v1/webhooks' && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: webhooks }))
      return
    }
    if (url.pathname === '/v1/webhooks' && req.method === 'POST') {
      readBody((body) => {
        const webhook = {
          id: `wh-new-${webhooks.length + 1}`,
          key: body.webhook?.key ?? 'hook',
          url: body.webhook?.url ?? 'https://example.test',
          active: true,
        }
        webhooks.push(webhook)
        res.statusCode = 201
        res.end(JSON.stringify(webhook))
      })
      return
    }
    if (url.pathname === '/v1/events' && req.method === 'GET') {
      res.statusCode = 200
      res.end(
        JSON.stringify({
          data: [
            {
              id: 'evt-outbox-1',
              event_type: 'person.created',
              resource_type: 'Person',
              resource_id: 'person-ava-0001',
            },
          ],
        }),
      )
      return
    }
    if (url.pathname === '/v1/scorecards' && req.method === 'POST') {
      readBody((body) => {
        const row = {
          id: `sc-${submittedScorecards.length}`,
          ...body.scorecard,
          user_id: actorId,
          status: 'submitted',
          user: Object.values(fixture.users).find((user) => user.id === actorId),
          can_edit: true,
        }
        submittedScorecards.push(row)
        res.statusCode = 201
        res.end(JSON.stringify(row))
      })
      return
    }
    const scorecardUpdate = url.pathname.match(/^\/v1\/scorecards\/([^/]+)$/)
    if (scorecardUpdate && req.method === 'PATCH') {
      readBody((body) => {
        const row = submittedScorecards.find((card) => card.id === scorecardUpdate[1])
        if (!row) {
          res.statusCode = 404
          res.end(JSON.stringify({ code: 'not_found' }))
          return
        }
        Object.assign(row, body.scorecard)
        res.statusCode = 200
        res.end(JSON.stringify(row))
      })
      return
    }

    const configPlans: any[] = (fixture as any).config_plans ?? []

    const compliancePolicies: any[] = (fixture as any).compliance_policies ?? []

    if (url.pathname === '/v1/config/plans' && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: configPlans }))
      return
    }
    if (url.pathname === '/v1/config/plans' && req.method === 'POST') {
      readBody((body) => {
        const plan = {
          id: `plan-${configPlans.length + 1}`,
          status: 'open',
          change_set: Array.isArray(body.documents)
            ? body.documents.map((d: any) => ({
                kind: d.kind,
                key: d.key,
                op: 'create',
              }))
            : [],
          manifest_hash: 'mock',
        }
        configPlans.push(plan)
        res.statusCode = 201
        res.end(JSON.stringify(plan))
      })
      return
    }
    if (url.pathname === '/v1/config/apply' && req.method === 'POST') {
      readBody((body) => {
        const plan = configPlans.find((p) => p.id === body.plan_id)
        if (!plan) {
          res.statusCode = 404
          res.end(JSON.stringify({ code: 'not_found' }))
          return
        }
        plan.status = 'applied'
        res.statusCode = 200
        res.end(JSON.stringify({ plan, applied: true }))
      })
      return
    }
    if (url.pathname === '/v1/affiliations' && req.method === 'GET') {
      const personId = url.searchParams.get('person_id')
      let rows = affiliations
      if (personId) rows = rows.filter((a: any) => a.person_id === personId)
      res.statusCode = 200
      res.end(JSON.stringify({ data: rows }))
      return
    }
    if (url.pathname === '/v1/affiliations' && req.method === 'POST') {
      readBody((body) => {
        const company = companies.find((c: any) => c.id === body.affiliation?.company_id)
        const row = {
          id: `aff-${affiliations.length + 1}`,
          person_id: body.affiliation?.person_id,
          company_id: body.affiliation?.company_id,
          title: body.affiliation?.title ?? null,
          current: true,
          company: company ? { id: company.id, name: company.name, domain: company.domain } : null,
        }
        affiliations.push(row)
        res.statusCode = 201
        res.end(JSON.stringify(row))
      })
      return
    }
    if (url.pathname === '/v1/compliance_policies' && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: compliancePolicies }))
      return
    }
    const eraseMatch = url.pathname.match(/^\/v1\/people\/([^/]+)\/erase$/)
    if (eraseMatch && req.method === 'POST') {
      res.statusCode = 200
      res.end(JSON.stringify({ id: eraseMatch[1], erased: true, verify: [] }))
      return
    }

    if (url.pathname === '/v1/saved_searches' && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: [] }))
      return
    }
    if (url.pathname === '/v1/saved_searches' && req.method === 'POST') {
      readBody((body) => {
        res.statusCode = 201
        res.end(
          JSON.stringify({
            id: 'search-1',
            name: body.saved_search?.name ?? 'Saved',
            filters: body.saved_search?.filters ?? {},
          }),
        )
      })
      return
    }
    if (url.pathname === '/v1/message_templates' && req.method === 'GET') {
      res.statusCode = 200
      res.end(
        JSON.stringify({
          data: (fixture as any).message_templates ?? [
            {
              id: 'tpl-outreach-1',
              key: 'outreach-1',
              name: 'First outreach',
              subject: 'Hello {{first_name}}',
            },
            { id: 'tpl-follow-up', key: 'follow-up', name: 'Follow-up', subject: 'Following up' },
          ],
        }),
      )
      return
    }
    if (url.pathname === '/v1/application_form' && req.method === 'GET') {
      res.statusCode = 200
      res.end(
        JSON.stringify({
          required_fields: ['display_name', 'email'],
          standard_fields: ['display_name', 'email'],
          screening_questions: [],
        }),
      )
      return
    }
    if (url.pathname === '/v1/calendar_connections' && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: [] }))
      return
    }
    if (url.pathname === '/v1/imports' && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: [] }))
      return
    }
    if (url.pathname === '/v1/scorecards' && req.method === 'GET') {
      const applicationId = url.searchParams.get('application_id')
      const ids = bookedInterviews
        .filter((row) => !applicationId || row.application_id === applicationId)
        .map((row) => row.id)
      res.statusCode = 200
      res.end(JSON.stringify({ data: submittedScorecards.filter((row) => ids.includes(row.interview_id)) }))
      return
    }
    if (url.pathname === '/v1/scorecard_rubrics' && req.method === 'GET') {
      res.statusCode = 200
      res.end(JSON.stringify({ data: [] }))
      return
    }

    res.statusCode = 404
    res.end(JSON.stringify({ code: 'not_found', path: url.pathname }))
  })

  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const address = server.address()
  if (!address || typeof address === 'string') throw new Error('expected TCP address')
  const baseUrl = `http://127.0.0.1:${address.port}`

  return {
    fixture,
    baseUrl,
    async close() {
      await new Promise<void>((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()))
      })
    },
  }
}
