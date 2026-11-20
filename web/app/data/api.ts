import { signedIn } from './auth.ts'

function apiBase(): string {
  return process.env.RAILS_API_URL ?? 'http://127.0.0.1:3000'
}

/** Server-side credentials for a Rails call. Never built from URL parameters. */
export type ApiHeaders = {
  token: string
  actingAgentId?: string
}

export type PipelineStage = {
  key: string
  name?: string
  type?: string
  interviews?: Array<{
    key: string
    name?: string
    required?: boolean
    rubric_key?: string
    duration_minutes?: number
  }>
  exit?: { require?: Array<{ scorecards_submitted?: { interviews?: 'required' | 'all' | string[] } }> }
  exit_requirements?: Array<{ scorecards_submitted?: { interviews?: 'required' | 'all' | string[] } }>
}

export type PipelineSummary = {
  id: string
  stages: PipelineStage[]
}

export type Person = {
  id: string
  display_name: string
  primary_email?: string | null
  primary_phone?: string | null
  lifecycle_stage?: string
  visibility?: string
  do_not_contact?: boolean
  do_not_contact_reason?: string | null
  owner_user_id?: string | null
  owner?: { id: string; name?: string | null; email?: string | null } | null
  headline?: string | null
  current_title?: string | null
  city?: string | null
  time_zone?: string | null
  source?: string | null
  source_detail?: string | null
  engagement_status?: string
  last_contacted_at?: string | null
  last_replied_at?: string | null
  last_activity_at?: string | null
}

export type JobDimension = {
  key: string
  label: string
  value: string
}

export type HiringTeamMemberSummary = {
  id: string
  user_id: string
  name?: string | null
  email?: string | null
  role: string
}

export type CareersVisibility = 'public' | 'internal' | 'both' | 'hidden'

export type Job = {
  careers_visibility?: CareersVisibility
  careers_published?: boolean
  id: string
  title: string
  status: string
  openings?: number
  confidential?: boolean
  code_name?: string | null
  pipeline_id?: string
  requisition_id?: string | null
  pipeline?: PipelineSummary | null
  requisition?: { id: string; code: string; title: string; headcount: number; status: string } | null
  dimensions?: JobDimension[]
  hiring_team?: HiringTeamMemberSummary[]
  /** Active members who can be put on the hiring team (job detail only). */
  assignable_members?: Array<{
    user_id: string
    name: string | null
    email: string | null
    role_key: string | null
  }>
  /** The posting the job page edits (published first). */
  posting?: Pick<
    JobPosting,
    'id' | 'title' | 'description' | 'location' | 'employment_type' | 'audience' | 'status' | 'version'
  > | null
}

export type HiringTeamRole = 'hiring-manager' | 'recruiter' | 'coordinator' | 'interviewer'

export type PipelineEdit =
  | { op: 'add_stage'; name: string; type: string }
  | { op: 'rename_stage'; key: string; name: string }
  | { op: 'move_stage'; key: string; direction: 'up' | 'down' }
  | { op: 'remove_stage'; key: string }
  | {
      op: 'add_interview'
      key: string
      name: string
      required: boolean
      rubric_key?: string
      duration_minutes?: number
    }
  | { op: 'remove_interview'; key: string; interview_key: string }

export async function updateJobPipeline(ctx: ApiHeaders, jobId: string, edit: PipelineEdit) {
  const res = await fetch(`${apiBase()}/v1/jobs/${jobId}/pipeline`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('pipeline') }),
    body: JSON.stringify(edit),
  })
  return json<Job>(res, 'edit pipeline')
}

export async function updateHiringTeamMember(
  ctx: ApiHeaders,
  jobId: string,
  memberId: string,
  teamRole: HiringTeamRole,
) {
  const res = await fetch(`${apiBase()}/v1/jobs/${jobId}/hiring_team/members/${memberId}`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('team-role') }),
    body: JSON.stringify({ team_role: teamRole }),
  })
  return json<Job>(res, 'change hiring team role')
}

export async function removeHiringTeamMember(ctx: ApiHeaders, jobId: string, memberId: string) {
  const res = await fetch(`${apiBase()}/v1/jobs/${jobId}/hiring_team/members/${memberId}/remove`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('team-remove') }),
    body: '{}',
  })
  return json<Job>(res, 'remove hiring team member')
}

export async function addHiringTeamMember(
  ctx: ApiHeaders,
  jobId: string,
  member: { user_id: string; team_role: HiringTeamRole },
) {
  const res = await fetch(`${apiBase()}/v1/jobs/${jobId}/hiring_team/members`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('team-add') }),
    body: JSON.stringify(member),
  })
  return json<Job>(res, 'add hiring team member')
}

export type Requisition = {
  id: string
  code: string
  title: string
  headcount: number
  status: string
  filled_count?: number
  openings_remaining?: number
  employment_type?: string | null
  jobs?: Array<Pick<Job, 'id' | 'title' | 'status'>>
}

export type Referral = {
  id: string
  person_id: string
  referrer_user_id: string
  job_id?: string | null
  application_id?: string | null
  status: string
  note?: string | null
  person?: Pick<Person, 'id' | 'display_name' | 'primary_email'> | null
  job?: Pick<Job, 'id' | 'title' | 'status'> | null
}

export type RediscoveryHit = {
  person: Pick<Person, 'id' | 'display_name' | 'primary_email' | 'lifecycle_stage'>
  score: number
  reasons: string[]
  past_applications?: Array<{
    id: string
    job_id: string
    status: string
    job?: Pick<Job, 'id' | 'title' | 'status'> | null
  }>
}

export type FunnelAnalytics = {
  total_applications: number
  hired: number
  rejected: number
  applications_by_status: Record<string, number>
  active_by_stage: Record<string, number>
}

export type SourcingAnalytics = {
  enrollments_by_status: Record<string, number>
  stop_reasons: Record<string, number>
  outbound_messages: number
  inbound_replies: number
  reply_rate: number
  referrals_by_status: Record<string, number>
  active_sequences: number
}

export type ApplicationOfferSummary = {
  id: string
  status: string
  current_version_id?: string | null
  created_at?: string
}

export type Application = {
  posting_id?: string | null
  application_form_snapshot?: ScreeningQuestion[] | null
  application_answers?: Record<string, unknown> | null
  id: string
  job_id: string
  person_id: string
  status: string
  current_stage_key?: string
  pipeline_id?: string
  person?: Pick<Person, 'id' | 'display_name' | 'primary_email' | 'lifecycle_stage'> | null
  job?: Pick<Job, 'id' | 'title' | 'status'> | null
  pipeline?: PipelineSummary | null
  offers?: ApplicationOfferSummary[]
  /** Closed applications only (list endpoint): the reject/withdraw/hire reason and when. */
  closed_reason?: string | null
  closed_at?: string | null
}

export type StageTransition = {
  id: string
  from_stage_key?: string | null
  to_stage_key: string
  command: string
  reason?: string | null
  actor_id?: string | null
  created_at?: string
}

export type Offer = {
  id: string
  application_id: string
  status: string
  current_version_id?: string | null
  fields?: Record<string, unknown> | null
  application?: {
    id: string
    job_id: string
    person_id: string
    status: string
    current_stage_key?: string
  } | null
  pending_approvals?: Array<{
    id: string
    status: string
    approver_user_id?: string | null
    step_position?: number
  }>
  approvals?: OfferApprovalRow[]
  checklist?: Partial<Record<OfferChecklistItem, { state: string; note?: string; updated_at?: string }>>
  /** Terms exist but the caller's role may not see compensation. */
  terms_hidden?: boolean
  /** True for an owner who can approve a pending step assigned to someone else. */
  can_override?: boolean
  send?: { token?: string; to_email?: string; signature_request_id?: string }
}

export type OfferChecklistItem = 'references' | 'verbal'

export type OfferApprovalRow = {
  id: string
  status: string
  step_position?: number | null
  approved_at?: string | null
  is_override?: boolean
  reason?: string | null
  approver_name?: string | null
  approved_by_name?: string | null
}

export async function updateOfferChecklist(
  ctx: ApiHeaders,
  offerId: string,
  body: { item: OfferChecklistItem; state: string; note?: string },
) {
  const res = await fetch(`${apiBase()}/v1/offers/${offerId}/checklist`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('offer-checklist') }),
    body: JSON.stringify(body),
  })
  return json<Offer>(res, 'update offer checklist')
}

export type TimelineEvent = {
  id: string
  person_id: string
  event_type: string
  payload?: Record<string, unknown>
  occurred_at?: string
}

export type Interview = {
  id: string
  application_id: string
  stage_key?: string
  interview_key: string
  status: string
  interviewer_user_ids?: string[]
  /** Who has submitted feedback. Everyone on the application sees this; the scorecards themselves are filtered. */
  feedback_submitted_user_ids?: string[]
  starts_at?: string
  ends_at?: string
}

export type Project = {
  id: string
  name: string
  job_id?: string | null
  pipeline_id?: string | null
  confidential?: boolean
  member_count?: number
  saved_search_id?: string | null
  pipeline?: PipelineSummary | null
  job?: Pick<Job, 'id' | 'title' | 'status'> | null
}

export type ProjectMember = {
  id: string
  project_id: string
  person_id: string
  pipeline_id?: string | null
  current_stage_key?: string | null
  status: string
  converted_application_id?: string | null
  person?: Pick<Person, 'id' | 'display_name' | 'primary_email' | 'lifecycle_stage'> | null
  project?: Pick<Project, 'id' | 'name' | 'job_id'> | null
  pipeline?: PipelineSummary | null
}

export type SchedulingLink = {
  id: string
  application_id: string
  kind: string
  interview_keys: string[]
  expires_at?: string
  token: string
}

function headers(ctx: ApiHeaders, extra?: HeadersInit): HeadersInit {
  return {
    Accept: 'application/json',
    'Content-Type': 'application/json',
    Authorization: `Bearer ${ctx.token}`,
    'X-Bigbuck-Surface': 'web',
    ...(signedIn()?.lab ? { 'X-Bigbuck-Demo-Generation': String(signedIn()!.lab!.generation) } : {}),
    ...(ctx.actingAgentId ? { 'X-Bigbuck-Act-As-Agent': ctx.actingAgentId } : {}),
    ...extra,
  }
}

async function json<T>(res: Response, label: string): Promise<T> {
  if (!res.ok) return problem(res, label)
  return (await res.json()) as T
}

function idempotencyKey(prefix: string) {
  return `${prefix}-${crypto.randomUUID()}`
}

export async function listPeople(
  ctx: ApiHeaders,
  filters?: {
    q?: string
    lifecycle_stage?: string
    do_not_contact?: string
    owner_user_id?: string
    project_id?: string
    tag?: string
    source?: string
    engagement_status?: string
    location?: string
    not_contacted_days?: string
    page?: number
    limit?: number
    sort?: 'name' | 'activity' | 'relevance'
  },
) {
  const url = new URL(`${apiBase()}/v1/people`)
  for (const key of ['tag', 'source', 'engagement_status', 'location', 'not_contacted_days'] as const) {
    const value = filters?.[key]
    if (value) url.searchParams.set(key, value)
  }
  if (filters?.page) url.searchParams.set('page', String(filters.page))
  if (filters?.limit) url.searchParams.set('limit', String(filters.limit))
  if (filters?.sort) url.searchParams.set('sort', filters.sort)
  if (filters?.q) url.searchParams.set('q', filters.q)
  if (filters?.lifecycle_stage) url.searchParams.set('lifecycle_stage', filters.lifecycle_stage)
  if (filters?.do_not_contact) url.searchParams.set('do_not_contact', filters.do_not_contact)
  if (filters?.owner_user_id) url.searchParams.set('owner_user_id', filters.owner_user_id)
  if (filters?.project_id) url.searchParams.set('project_id', filters.project_id)
  const res = await fetch(url, { headers: headers(ctx) })
  return json<{ data: Person[]; meta?: { page: number; per_page: number; total: number } }>(res, 'people')
}

export async function bulkPeopleAction(
  ctx: ApiHeaders,
  body: {
    bulk_action: 'enroll_sequence' | 'set_dnc' | 'clear_dnc' | 'add_to_project'
    person_ids: string[]
    sequence_id?: string
    mailbox_id?: string
    project_id?: string
    reason?: string
  },
) {
  const res = await fetch(`${apiBase()}/v1/people/bulk`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('bulk') }),
    body: JSON.stringify(body),
  })
  return json<{ action: string; results: Array<{ person_id: string; ok: boolean; error?: string }> }>(
    res,
    'bulk people',
  )
}

export type PersonDocument = {
  id: string
  filename: string
  content_type: string
  byte_size: number
  scan_status: 'pending' | 'clean' | 'infected' | 'failed'
  created_at: string
  downloadable: boolean
}

export async function listPersonDocuments(ctx: ApiHeaders, personId: string) {
  const res = await fetch(`${apiBase()}/v1/people/${encodeURIComponent(personId)}/documents`, {
    headers: headers(ctx),
  })
  return json<{ data: PersonDocument[] }>(res, 'person documents')
}

export async function getPersonDocument(
  ctx: ApiHeaders,
  personId: string,
  documentId: string,
  download: boolean,
) {
  return fetch(
    `${apiBase()}/v1/people/${encodeURIComponent(personId)}/documents/${encodeURIComponent(documentId)}${download ? '?download=true' : ''}`,
    { headers: headers(ctx, { Accept: '*/*' }) },
  )
}

export async function getPerson(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/people/${id}`, { headers: headers(ctx) })
  return json<Person>(res, 'person')
}

export async function updatePerson(
  ctx: ApiHeaders,
  personId: string,
  person: {
    display_name?: string
    email?: string
    phone?: string
    affiliation?: { id?: string; company_id: string; title?: string }
  },
) {
  const res = await fetch(`${apiBase()}/v1/people/${encodeURIComponent(personId)}`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('person-edit') }),
    body: JSON.stringify({ person }),
  })
  return json<Person>(res, 'update person')
}

export async function replacePersonResume(ctx: ApiHeaders, personId: string, file: File) {
  const body = new FormData()
  body.set('file', file, file.name)
  const uploadHeaders = new Headers(headers(ctx, { 'Idempotency-Key': idempotencyKey('resume') }))
  uploadHeaders.delete('Content-Type')
  const res = await fetch(`${apiBase()}/v1/people/${encodeURIComponent(personId)}/documents`, {
    method: 'POST',
    headers: uploadHeaders,
    body,
  })
  return json<PersonDocument>(res, 'upload resume')
}

export async function createPerson(
  ctx: ApiHeaders,
  person: { display_name: string; email?: string; phone?: string },
) {
  const res = await fetch(`${apiBase()}/v1/people`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('person') }),
    body: JSON.stringify({ person }),
  })
  return json<Person & { attached?: boolean }>(res, 'create person')
}

export async function listJobs(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/jobs`, { headers: headers(ctx) })
  return json<{ data: Job[] }>(res, 'jobs')
}

export async function getJob(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/jobs/${id}`, { headers: headers(ctx) })
  return json<Job>(res, 'job')
}

export async function updateJob(
  ctx: ApiHeaders,
  id: string,
  job: { openings?: number; careers_visibility?: CareersVisibility; careers_published?: boolean },
) {
  const res = await fetch(`${apiBase()}/v1/jobs/${id}`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('job-update') }),
    body: JSON.stringify({ job }),
  })
  return json<Job>(res, 'update job')
}

export async function createJob(
  ctx: ApiHeaders,
  job: {
    title: string
    status?: string
    requisition_id?: string
    careers_visibility?: CareersVisibility
    description?: string
    location?: string
    employment_type?: string
    question_template_id?: string
    department_id?: string
    hiring_manager_user_id?: string
  },
) {
  const res = await fetch(`${apiBase()}/v1/jobs`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('job') }),
    body: JSON.stringify({ job }),
  })
  return json<Job>(res, 'create job')
}

export type JobFormOptions = {
  departments: Array<{ id: string; key: string; label: string }>
  members: Array<{ user_id: string; name: string; email: string; role_key?: string | null }>
}

/** Departments and members the new-job form can choose from. */
export async function getJobFormOptions(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/jobs/form_options`, { headers: headers(ctx) })
  return json<JobFormOptions>(res, 'job form options')
}

export async function rediscoverTalent(ctx: ApiHeaders, jobId: string) {
  const res = await fetch(`${apiBase()}/v1/jobs/${jobId}/rediscovery`, { headers: headers(ctx) })
  return json<{ data: RediscoveryHit[] }>(res, 'rediscovery')
}

export async function listRequisitions(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/requisitions`, { headers: headers(ctx) })
  return json<{ data: Requisition[] }>(res, 'requisitions')
}

export async function createRequisition(
  ctx: ApiHeaders,
  requisition: { code: string; title: string; headcount?: number; employment_type?: string },
) {
  const res = await fetch(`${apiBase()}/v1/requisitions`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('req') }),
    body: JSON.stringify({ requisition }),
  })
  return json<Requisition>(res, 'create requisition')
}

export async function openRequisition(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/requisitions/${id}/open`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('req-open') }),
  })
  return json<Requisition>(res, 'open requisition')
}

export async function listReferrals(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/referrals`, { headers: headers(ctx) })
  return json<{ data: Referral[] }>(res, 'referrals')
}

export async function createReferral(
  ctx: ApiHeaders,
  referral: { display_name: string; email?: string; job_id?: string; note?: string },
) {
  const res = await fetch(`${apiBase()}/v1/referrals`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('referral') }),
    body: JSON.stringify({ referral }),
  })
  return json<Referral>(res, 'create referral')
}

export async function getFunnelAnalytics(ctx: ApiHeaders, jobId?: string) {
  const url = new URL(`${apiBase()}/v1/analytics/funnel`)
  if (jobId) url.searchParams.set('job_id', jobId)
  const res = await fetch(url, { headers: headers(ctx) })
  return json<FunnelAnalytics>(res, 'funnel analytics')
}

export async function getSourcingAnalytics(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/analytics/sourcing`, { headers: headers(ctx) })
  return json<SourcingAnalytics>(res, 'sourcing analytics')
}

export type OutreachFunnel = {
  from: string
  to: string
  sequence_id?: string | null
  enrolled: number
  contacted: number
  replied: number
  reply_rate: number
  by_classification: Record<string, number>
  positive_replies: number
  applied: number
  hired: number
}

/** Outreach results for the last 30 days, for the whole organization or one sequence. Counts distinct people. */
export async function getOutreachFunnel(ctx: ApiHeaders, sequenceId?: string) {
  const url = new URL(`${apiBase()}/v1/analytics/outreach`)
  if (sequenceId) url.searchParams.set('sequence_id', sequenceId)
  const res = await fetch(url, { headers: headers(ctx) })
  return json<OutreachFunnel>(res, 'outreach analytics')
}

export type ApplicationPage = {
  data: Application[]
  meta?: { page: number; per_page: number; total: number }
}

export async function listApplications(
  ctx: ApiHeaders,
  filters?: {
    jobId?: string
    personId?: string
    stage?: string
    status?: string
    sort?: string
    page?: number
    perPage?: number
  },
) {
  const url = new URL(`${apiBase()}/v1/applications`)
  if (filters?.jobId) url.searchParams.set('job_id', filters.jobId)
  if (filters?.personId) url.searchParams.set('person_id', filters.personId)
  if (filters?.stage) url.searchParams.set('stage', filters.stage)
  if (filters?.status) url.searchParams.set('status', filters.status)
  if (filters?.sort) url.searchParams.set('sort', filters.sort)
  if (filters?.page) url.searchParams.set('page', String(filters.page))
  if (filters?.perPage) url.searchParams.set('per_page', String(filters.perPage))
  const res = await fetch(url, { headers: headers(ctx) })
  return json<ApplicationPage>(res, 'applications')
}

export async function getApplication(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/applications/${id}`, { headers: headers(ctx) })
  return json<Application>(res, 'application')
}

export async function createApplication(
  ctx: ApiHeaders,
  application: { job_id: string; person_id: string; consents?: string[]; locale?: string },
) {
  const res = await fetch(`${apiBase()}/v1/applications`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('application') }),
    body: JSON.stringify({ application }),
  })
  return json<Application>(res, 'create application')
}

export async function listApplicationTransitions(ctx: ApiHeaders, applicationId: string) {
  const res = await fetch(`${apiBase()}/v1/applications/${applicationId}/transitions`, {
    headers: headers(ctx),
  })
  return json<{ data: StageTransition[] }>(res, 'transitions')
}

export async function createApplicationTransition(
  ctx: ApiHeaders,
  applicationId: string,
  body: { command?: string; to_stage_key?: string; reason?: string },
) {
  const res = await fetch(`${apiBase()}/v1/applications/${applicationId}/transitions`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('transition') }),
    body: JSON.stringify(body),
  })
  return json<Application>(res, 'create transition')
}

export async function listOffers(ctx: ApiHeaders, applicationId?: string) {
  const url = new URL(`${apiBase()}/v1/offers`)
  if (applicationId) url.searchParams.set('application_id', applicationId)
  const res = await fetch(url, { headers: headers(ctx) })
  return json<{ data: Offer[] }>(res, 'offers')
}

export async function getOffer(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/offers/${id}`, { headers: headers(ctx) })
  return json<Offer>(res, 'offer')
}

export async function createOffer(
  ctx: ApiHeaders,
  applicationId: string,
  fields: Record<string, unknown> = {},
) {
  const res = await fetch(`${apiBase()}/v1/applications/${applicationId}/offers`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('offer') }),
    body: JSON.stringify({ offer: { fields } }),
  })
  return json<Offer>(res, 'create offer')
}

export async function submitOffer(ctx: ApiHeaders, offerId: string) {
  const res = await fetch(`${apiBase()}/v1/offers/${offerId}/submit`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('submit') }),
    body: '{}',
  })
  return json<Offer>(res, 'submit offer')
}

export async function approveOffer(ctx: ApiHeaders, offerId: string, override = false) {
  const res = await fetch(`${apiBase()}/v1/offers/${offerId}/approve`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('approve') }),
    body: JSON.stringify({ override }),
  })
  return json<Offer>(res, 'approve offer')
}

/** Record the candidate's answer when it arrived outside the signed link. */
export async function recordOfferResponse(
  ctx: ApiHeaders,
  offerId: string,
  body: { response: 'accepted' | 'declined'; note?: string },
) {
  const res = await fetch(`${apiBase()}/v1/offers/${offerId}/record_response`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('offer-response') }),
    body: JSON.stringify(body),
  })
  return json<{ id: string; status: string; hired: boolean }>(res, 'record offer response')
}

export async function sendOffer(
  ctx: ApiHeaders,
  offerId: string,
  opts: { template_key?: string; to_email?: string } = {},
) {
  const res = await fetch(`${apiBase()}/v1/offers/${offerId}/send`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('send') }),
    body: JSON.stringify(opts),
  })
  return json<Offer>(res, 'send offer')
}

/** A fresh candidate link for an offer that is already sent (same letter and expiry). */
export async function resendOffer(ctx: ApiHeaders, offerId: string) {
  const res = await fetch(`${apiBase()}/v1/offers/${offerId}/resend`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('resend') }),
    body: '{}',
  })
  return json<Offer>(res, 'resend offer')
}

export async function rescindOffer(ctx: ApiHeaders, offerId: string, reason_key: string) {
  const res = await fetch(`${apiBase()}/v1/offers/${offerId}/rescind`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('rescind') }),
    body: JSON.stringify({ reason_key }),
  })
  return json<Offer>(res, 'rescind offer')
}

export async function getPersonTimeline(ctx: ApiHeaders, personId: string) {
  const res = await fetch(`${apiBase()}/v1/people/${personId}/timeline`, { headers: headers(ctx) })
  return json<{ data: TimelineEvent[] }>(res, 'timeline')
}

export async function sendCommunication(
  ctx: ApiHeaders,
  personId: string,
  body: {
    subject?: string
    body?: string
    template_key?: string
    message_type?: string
    mailbox_id?: string
    thread_id?: string
    in_reply_to?: string
  },
) {
  const res = await fetch(`${apiBase()}/v1/people/${personId}/communications`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('comm') }),
    body: JSON.stringify(body),
  })
  return json<{ id: string; status: string; subject: string }>(res, 'send communication')
}

export type FeedItem = {
  id: string
  type: string
  kind: 'email' | 'note' | 'task' | 'tag' | 'event'
  occurred_at: string
  direction?: 'outbound' | 'inbound'
  subject?: string | null
  body?: string | null
  thread_id?: string | null
  rfc822_message_id?: string | null
  classification?: string | null
  communication_id?: string
  mailbox_id?: string | null
  note_id?: string
  pinned?: boolean
  author?: string | null
  title?: string
  task_type?: string
  task_id?: string | null
  status?: string | null
  due_at?: string | null
  tag?: string
}

export type PersonTagRow = { id: string; name: string; color: string; person_count?: number | null }

export async function getPersonFeed(ctx: ApiHeaders, personId: string) {
  const res = await fetch(`${apiBase()}/v1/people/${personId}/feed`, { headers: headers(ctx) })
  return json<{ data: FeedItem[] }>(res, 'feed')
}

export async function previewPersonMessage(
  ctx: ApiHeaders,
  personId: string,
  body: { template_key?: string; subject?: string; body?: string; mailbox_id?: string },
) {
  const res = await fetch(`${apiBase()}/v1/people/${personId}/preview_message`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('preview') }),
    body: JSON.stringify(body),
  })
  return json<{ subject: string; body: string }>(res, 'preview message')
}

export async function listTags(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/tags`, { headers: headers(ctx) })
  return json<{ data: PersonTagRow[] }>(res, 'tags')
}

export async function listPersonTags(ctx: ApiHeaders, personId: string) {
  const res = await fetch(`${apiBase()}/v1/people/${personId}/tags`, { headers: headers(ctx) })
  return json<{ data: PersonTagRow[] }>(res, 'person tags')
}

export async function tagPerson(ctx: ApiHeaders, personId: string, name: string) {
  const res = await fetch(`${apiBase()}/v1/people/${personId}/tags`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('tag') }),
    body: JSON.stringify({ name }),
  })
  return json<PersonTagRow>(res, 'tag person')
}

export async function untagPerson(ctx: ApiHeaders, personId: string, tagId: string) {
  const res = await fetch(`${apiBase()}/v1/people/${personId}/tags/${encodeURIComponent(tagId)}`, {
    method: 'DELETE',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('untag') }),
  })
  if (!res.ok) await json(res, 'untag person')
}

export async function addPersonNote(ctx: ApiHeaders, personId: string, body: string, pinned = false) {
  const res = await fetch(`${apiBase()}/v1/people/${personId}/notes`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('note') }),
    body: JSON.stringify({ note: { body, pinned } }),
  })
  return json<{ id: string }>(res, 'add note')
}

export async function pinPersonNote(ctx: ApiHeaders, noteId: string, pinned: boolean) {
  const res = await fetch(`${apiBase()}/v1/notes/${encodeURIComponent(noteId)}`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('note') }),
    body: JSON.stringify({ note: { pinned } }),
  })
  return json<{ id: string }>(res, 'pin note')
}

export async function createFollowUp(
  ctx: ApiHeaders,
  task: { person_id: string; title: string; task_type?: string; due_at?: string },
) {
  const res = await fetch(`${apiBase()}/v1/tasks`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('task') }),
    body: JSON.stringify({ task }),
  })
  return json<{ id: string }>(res, 'create task')
}

export async function listInterviews(ctx: ApiHeaders, applicationId: string) {
  const res = await fetch(`${apiBase()}/v1/applications/${applicationId}/interviews`, {
    headers: headers(ctx),
  })
  return json<{ data: Interview[] }>(res, 'interviews')
}

export async function getInterview(ctx: ApiHeaders, interviewId: string) {
  const res = await fetch(`${apiBase()}/v1/interviews/${interviewId}`, { headers: headers(ctx) })
  return json<Interview>(res, 'interview')
}

/** Required interviews in the candidate's current stage that still need submitted feedback. A warning
 * for whoever moves them; `blocking` is true only when the stage's own exit rules hold the move. */
export async function getMissingFeedback(ctx: ApiHeaders, applicationId: string) {
  const res = await fetch(`${apiBase()}/v1/applications/${applicationId}/missing_feedback`, {
    headers: headers(ctx),
  })
  return json<{ stage_key: string; blocking?: boolean; data: Array<{ key: string; name: string }> }>(
    res,
    'missing feedback',
  )
}

export async function createSchedulingLink(
  ctx: ApiHeaders,
  applicationId: string,
  interviewKeys: string[] = ['screen'],
) {
  const res = await fetch(`${apiBase()}/v1/applications/${applicationId}/scheduling_links`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('schedlink') }),
    body: JSON.stringify({ interview_keys: interviewKeys }),
  })
  return json<SchedulingLink>(res, 'scheduling link')
}

export async function getPublicScheduling(token: string) {
  const res = await fetch(`${apiBase()}/v1/public/scheduling/${encodeURIComponent(token)}`, {
    headers: { Accept: 'application/json' },
  })
  return json<{
    id: string
    kind: string
    usable: boolean
    expires_at?: string
    organization?: { name: string; slug?: string }
    application?: { id: string; job_title?: string; person_name?: string }
  }>(res, 'public scheduling')
}

export async function declinePublicOffer(token: string, reasonKey?: string) {
  const res = await fetch(`${apiBase()}/v1/public/offers/${encodeURIComponent(token)}/decline`, {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify({ reason_key: reasonKey }),
  })
  return json<{ status: string; hired: boolean }>(res, 'decline')
}

export async function listProjects(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/projects`, { headers: headers(ctx) })
  return json<{ data: Project[] }>(res, 'projects')
}

export async function getProject(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/projects/${id}`, { headers: headers(ctx) })
  return json<Project>(res, 'project')
}

export async function createProject(ctx: ApiHeaders, project: { name: string; job_id?: string }) {
  const res = await fetch(`${apiBase()}/v1/projects`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('project') }),
    body: JSON.stringify({ project }),
  })
  return json<Project>(res, 'create project')
}

export async function listProjectMembers(
  ctx: ApiHeaders,
  filters?: { projectId?: string; personId?: string },
) {
  if (filters?.projectId) {
    const res = await fetch(`${apiBase()}/v1/projects/${filters.projectId}/members`, {
      headers: headers(ctx),
    })
    return json<{ data: ProjectMember[] }>(res, 'project members')
  }
  const url = new URL(`${apiBase()}/v1/project_members`)
  if (filters?.personId) url.searchParams.set('person_id', filters.personId)
  const res = await fetch(url, { headers: headers(ctx) })
  return json<{ data: ProjectMember[] }>(res, 'project members')
}

export async function addProjectMember(ctx: ApiHeaders, projectId: string, personId: string) {
  const res = await fetch(`${apiBase()}/v1/projects/${projectId}/members`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('member') }),
    body: JSON.stringify({ member: { person_id: personId } }),
  })
  return json<ProjectMember>(res, 'add project member')
}

export async function getProjectMember(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/project_members/${id}`, { headers: headers(ctx) })
  return json<ProjectMember>(res, 'project member')
}

export async function listProjectMemberTransitions(ctx: ApiHeaders, memberId: string) {
  const res = await fetch(`${apiBase()}/v1/project_members/${memberId}/transitions`, {
    headers: headers(ctx),
  })
  return json<{ data: StageTransition[] }>(res, 'member transitions')
}

export async function createProjectMemberTransition(
  ctx: ApiHeaders,
  memberId: string,
  body: { command?: string; to_stage_key?: string; reason?: string },
) {
  const res = await fetch(`${apiBase()}/v1/project_members/${memberId}/transitions`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('member-transition') }),
    body: JSON.stringify(body),
  })
  return json<ProjectMember>(res, 'create member transition')
}

export async function convertProjectMember(ctx: ApiHeaders, memberId: string, jobId?: string) {
  const res = await fetch(`${apiBase()}/v1/project_members/${memberId}/convert`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('convert') }),
    body: JSON.stringify(jobId ? { job_id: jobId } : {}),
  })
  return json<{ member: ProjectMember; application: Application }>(res, 'convert member')
}

export type Sequence = {
  id: string
  key: string
  name: string
  status: string
  shared?: boolean
  is_template?: boolean
  steps?: Array<Record<string, unknown>>
  enrollment_count?: number
}

export type Enrollment = {
  id: string
  sequence_id: string
  person_id: string
  mailbox_id: string
  step_index: number
  status: string
  stop_reason?: string | null
  person?: Pick<Person, 'id' | 'display_name' | 'primary_email'> | null
  sequence?: Pick<Sequence, 'id' | 'key' | 'name'> | null
  mailbox?: { id: string; email: string; kind: string } | null
}

export type Mailbox = {
  id: string
  kind: string
  email: string
  /** The member this mailbox belongs to; absent for a shared mailbox. */
  user_id?: string | null
  status: string
  provider?: string
  daily_cap?: number
  sent_today?: number
}

export async function updateMailbox(
  ctx: ApiHeaders,
  id: string,
  mailbox: { status?: string; daily_cap?: number },
) {
  const res = await fetch(`${apiBase()}/v1/mailboxes/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('mailbox') }),
    body: JSON.stringify({ mailbox }),
  })
  return json<Mailbox>(res, 'update mailbox')
}

export async function createTestMailbox(ctx: ApiHeaders, email: string) {
  const res = await fetch(`${apiBase()}/v1/mailboxes`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('mailbox') }),
    body: JSON.stringify({ mailbox: { email, provider: 'sandbox', kind: 'personal' } }),
  })
  return json<Mailbox>(res, 'create test mailbox')
}

export type InboxMessage = {
  id: string
  direction: 'outbound' | 'inbound'
  rfc822_message_id: string
  thread_id: string
  from_address: string
  to_address: string
  subject?: string
  delivered_at: string
  answered: boolean
}

export async function listMailboxMessages(ctx: ApiHeaders, mailboxId: string) {
  const res = await fetch(`${apiBase()}/v1/mailboxes/${encodeURIComponent(mailboxId)}/messages`, {
    headers: headers(ctx),
  })
  return json<{ data: InboxMessage[] }>(res, 'inbox')
}

export async function simulateMailboxReply(
  ctx: ApiHeaders,
  mailboxId: string,
  messageId: string,
  kind: 'reply' | 'bounce' | 'auto_reply',
) {
  const res = await fetch(`${apiBase()}/v1/mailboxes/${encodeURIComponent(mailboxId)}/simulate`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('simulate') }),
    body: JSON.stringify({ message_id: messageId, kind }),
  })
  return json<InboxMessage>(res, 'simulate reply')
}

export type FollowUpTask = {
  id: string
  person_id: string
  title: string
  description?: string | null
  task_type: 'call' | 'linkedin' | 'email' | 'other'
  status: string
  due_at?: string | null
  overdue: boolean
  assignee_user_id?: string | null
  person?: { id: string; display_name: string; primary_email?: string | null }
}

export async function listFollowUps(ctx: ApiHeaders, query: Record<string, string> = {}) {
  const qs = new URLSearchParams(query).toString()
  const res = await fetch(`${apiBase()}/v1/tasks${qs ? `?${qs}` : ''}`, { headers: headers(ctx) })
  return json<{ data: FollowUpTask[] }>(res, 'tasks')
}

export async function completeFollowUp(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/tasks/${encodeURIComponent(id)}/complete`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('task') }),
  })
  return json<FollowUpTask>(res, 'complete task')
}

export async function cancelFollowUp(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/tasks/${encodeURIComponent(id)}/cancel`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('task') }),
  })
  return json<FollowUpTask>(res, 'cancel task')
}

export type Scorecard = {
  id: string
  interview_id: string
  user_id: string
  status: string
  rating?: string | null
  notes?: string | null
  attribute_ratings?: Record<string, string | number> | null
  user?: { id: string; name?: string | null; email?: string | null } | null
  created_at?: string | null
  updated_at?: string | null
  /** The signed-in user may correct this scorecard: its author, or someone with scorecard.manage. */
  can_edit?: boolean
}

export type Company = {
  id: string
  name: string
  domain?: string | null
  industry?: string | null
  employee_band?: string | null
  affiliation_count?: number
  current_count?: number
  former_count?: number
}

export type DncCompany = {
  id: string
  organization_id?: string
  company_id?: string | null
  domain?: string | null
  reason?: string | null
  created_at?: string
  company?: { id: string; name?: string | null; domain?: string | null } | null
}

export type OutboxEventRow = {
  id: string
  event_type: string
  resource_type: string
  resource_id: string
  created_at?: string
  payload?: Record<string, unknown>
}

export type WebhookEndpoint = {
  id: string
  key: string
  url: string
  active: boolean
  event_types?: string[] | null
  signing_secret?: string
  recent_deliveries?: Array<{
    id: string
    event_type: string
    status: string
    attempt_count: number
    response_status?: number | null
    last_error?: string | null
    delivered_at?: string | null
    created_at: string
  }>
}

export async function updateWebhook(
  ctx: ApiHeaders,
  id: string,
  webhook: { url?: string; event_types?: string[]; active?: boolean },
) {
  const res = await fetch(`${apiBase()}/v1/webhooks/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('webhook-update') }),
    body: JSON.stringify({ webhook }),
  })
  return json<WebhookEndpoint>(res, 'update webhook')
}

export async function rotateWebhookSecret(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/webhooks/${encodeURIComponent(id)}/rotate_secret`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('webhook-rotate') }),
  })
  return json<WebhookEndpoint>(res, 'rotate webhook secret')
}

export async function getSequence(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/sequences/${encodeURIComponent(id)}`, { headers: headers(ctx) })
  return json<Sequence>(res, 'sequence')
}

export async function listSequenceEnrollments(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/sequences/${encodeURIComponent(id)}/enrollments`, {
    headers: headers(ctx),
  })
  return json<{ data: Array<Enrollment & { created_at?: string; updated_at?: string }> }>(
    res,
    'sequence enrollments',
  )
}

export type AwaitingSchedule = {
  application_id: string
  person?: { id: string; display_name?: string | null } | null
  job?: { id: string; title: string } | null
  stage: { key: string; name?: string | null }
  missing: Array<{ key: string; name?: string | null; required?: boolean }>
  waiting_since?: string
}

export async function listAwaitingSchedule(ctx: ApiHeaders, scope?: 'mine' | 'all') {
  const url = new URL(`${apiBase()}/v1/interviews/awaiting_schedule`)
  if (scope === 'mine') url.searchParams.set('scope', 'mine')
  return json<{ data: AwaitingSchedule[] }>(await fetch(url, { headers: headers(ctx) }), 'awaiting schedule')
}

export type TeamMember = {
  user_id: string
  name: string | null
  email: string | null
  role_key: string | null
  role_name: string | null
  scoped: boolean
}

export type TeamRole = {
  key: string
  name: string
  system: boolean
  permissions: string[]
  member_count: number
}

export async function getTeam(ctx: ApiHeaders) {
  return json<{ data: TeamMember[]; roles: TeamRole[] }>(
    await fetch(`${apiBase()}/v1/team`, { headers: headers(ctx) }),
    'team',
  )
}

export async function listSequences(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/sequences`, { headers: headers(ctx) })
  return json<{ data: Sequence[] }>(res, 'sequences')
}

export async function createSequence(
  ctx: ApiHeaders,
  sequence: {
    key: string
    name: string
    shared?: boolean
    is_template?: boolean
    steps?: Array<Record<string, unknown>>
  },
) {
  const res = await fetch(`${apiBase()}/v1/sequences`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('sequence') }),
    body: JSON.stringify({ sequence }),
  })
  return json<Sequence>(res, 'create sequence')
}

export async function enrollInSequence(
  ctx: ApiHeaders,
  sequenceId: string,
  body: { person_id: string; mailbox_id?: string },
) {
  const res = await fetch(`${apiBase()}/v1/sequences/${sequenceId}/enrollments`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('enroll') }),
    body: JSON.stringify({ enrollment: body }),
  })
  return json<Enrollment>(res, 'enroll')
}

export async function listEnrollments(ctx: ApiHeaders, personId?: string) {
  const url = new URL(`${apiBase()}/v1/enrollments`)
  if (personId) url.searchParams.set('person_id', personId)
  const res = await fetch(url, { headers: headers(ctx) })
  return json<{ data: Enrollment[] }>(res, 'enrollments')
}

export async function stopEnrollment(ctx: ApiHeaders, enrollmentId: string, reason?: string) {
  const res = await fetch(`${apiBase()}/v1/enrollments/${enrollmentId}/stop`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('stop') }),
    body: JSON.stringify({ reason }),
  })
  return json<Enrollment>(res, 'stop enrollment')
}

export async function listMailboxes(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/mailboxes`, { headers: headers(ctx) })
  return json<{ data: Mailbox[] }>(res, 'mailboxes')
}

export type ScorecardRubric = {
  id: string
  key: string
  name: string
  guidance?: string | null
  attributes_spec?: Array<{
    key: string
    label?: string
    name?: string
    guidance?: string
    required?: boolean
  }>
}

export type ScorecardRubricInput = {
  name: string
  guidance?: string
  attributes_spec: Array<{ key: string; label: string; guidance?: string; required: boolean }>
}

export async function listScorecards(
  ctx: ApiHeaders,
  filters?: { applicationId?: string; interviewId?: string },
) {
  const url = new URL(`${apiBase()}/v1/scorecards`)
  if (filters?.applicationId) url.searchParams.set('application_id', filters.applicationId)
  if (filters?.interviewId) url.searchParams.set('interview_id', filters.interviewId)
  const res = await fetch(url, { headers: headers(ctx) })
  return json<{ data: Scorecard[] }>(res, 'scorecards')
}

export async function listScorecardRubrics(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/scorecard_rubrics`, { headers: headers(ctx) })
  return json<{ data: ScorecardRubric[] }>(res, 'rubrics')
}

export async function createScorecard(
  ctx: ApiHeaders,
  scorecard: {
    interview_id: string
    rating: string
    notes?: string
    user_id?: string
    attribute_ratings?: Record<string, string>
  },
) {
  const res = await fetch(`${apiBase()}/v1/scorecards`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('scorecard') }),
    body: JSON.stringify({ scorecard }),
  })
  return json<Scorecard>(res, 'scorecard')
}

export async function updateScorecard(
  ctx: ApiHeaders,
  id: string,
  scorecard: { rating: string; notes?: string; attribute_ratings?: Record<string, string> },
) {
  const res = await fetch(`${apiBase()}/v1/scorecards/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('scorecard') }),
    body: JSON.stringify({ scorecard }),
  })
  return json<Scorecard>(res, 'scorecard')
}

export async function createScorecardRubric(ctx: ApiHeaders, rubric: ScorecardRubricInput & { key: string }) {
  const res = await fetch(`${apiBase()}/v1/scorecard_rubrics`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('rubric') }),
    body: JSON.stringify({ scorecard_rubric: rubric }),
  })
  return json<ScorecardRubric>(res, 'scorecard')
}

export async function updateScorecardRubric(ctx: ApiHeaders, id: string, rubric: ScorecardRubricInput) {
  const res = await fetch(`${apiBase()}/v1/scorecard_rubrics/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('rubric') }),
    body: JSON.stringify({ scorecard_rubric: rubric }),
  })
  return json<ScorecardRubric>(res, 'scorecard')
}

export type PanelBookingInput = {
  organizer_calendar: string
  search_start: string
  search_end: string
  interview_defs: Array<{
    key: string
    duration_minutes: number
    count: number
    candidate_user_ids: string[]
  }>
  profiles: Array<{ user_id: string; paused?: boolean }>
  user_emails: Record<string, string>
}

export type BookingOption = {
  token: string
  starts_at: string
  ends_at: string
  blocks: Array<{ interview_key: string; starts_at: string; ends_at: string; user_ids: string[] }>
}

export async function previewPanel(ctx: ApiHeaders, applicationId: string, body: PanelBookingInput) {
  const res = await fetch(`${apiBase()}/v1/applications/${applicationId}/booking_options`, {
    method: 'POST',
    headers: headers(ctx),
    body: JSON.stringify(body),
  })
  return json<{ options: BookingOption[] }>(res, 'interview times')
}

export async function bookPanel(
  ctx: ApiHeaders,
  applicationId: string,
  body: PanelBookingInput | { booking_token: string },
) {
  const res = await fetch(`${apiBase()}/v1/applications/${applicationId}/bookings`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('booking') }),
    body: JSON.stringify(body),
  })
  return json<{ booked: boolean; interviews: Interview[] }>(res, 'book panel')
}

export async function listCompanies(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/companies`, { headers: headers(ctx) })
  return json<{ data: Company[] }>(res, 'companies')
}

export async function getCompany(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/companies/${id}`, { headers: headers(ctx) })
  return json<Company>(res, 'company')
}

export async function createCompany(ctx: ApiHeaders, company: { name: string; domain?: string }) {
  const res = await fetch(`${apiBase()}/v1/companies`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('company') }),
    body: JSON.stringify({ company }),
  })
  return json<Company>(res, 'create company')
}

export async function listDncCompanies(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/dnc_companies`, { headers: headers(ctx) })
  return json<{ data: DncCompany[] }>(res, 'dnc companies')
}

export async function createDncCompany(
  ctx: ApiHeaders,
  dnc_company: { company_id?: string; domain?: string; reason?: string },
) {
  const res = await fetch(`${apiBase()}/v1/dnc_companies`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('dnc') }),
    body: JSON.stringify({ dnc_company }),
  })
  return json<DncCompany>(res, 'create dnc company')
}

export async function deleteDncCompany(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/dnc_companies/${encodeURIComponent(id)}`, {
    method: 'DELETE',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('dnc-delete') }),
  })
  if (!res.ok) await json(res, 'delete dnc company')
}

export async function listEvents(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/events`, { headers: headers(ctx) })
  return json<{ data: OutboxEventRow[] }>(res, 'events')
}

export async function listWebhooks(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/webhooks`, { headers: headers(ctx) })
  return json<{ data: WebhookEndpoint[] }>(res, 'webhooks')
}

export async function createWebhook(
  ctx: ApiHeaders,
  webhook: { key: string; url: string; secret_ref?: string },
) {
  const res = await fetch(`${apiBase()}/v1/webhooks`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('webhook') }),
    body: JSON.stringify({ webhook }),
  })
  return json<WebhookEndpoint>(res, 'create webhook')
}

export async function createSession(body: { email: string; organization_id?: string; slug?: string }) {
  const res = await fetch(`${apiBase()}/v1/sessions`, {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  return json<SessionResponse>(res, 'session')
}

export type SessionResponse = {
  organization: { id: string; name: string; slug: string }
  user: { id: string; email: string; name: string }
  session: { token: string; expires_at: string }
}

/** Trades the one-time code from Google sign-in for a session (server-side only). */
export async function exchangeSessionCode(code: string) {
  const res = await fetch(`${apiBase()}/v1/sessions/exchange`, {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify({ code }),
  })
  return json<SessionResponse>(res, 'session exchange')
}

/** Revokes the session token on the Rails side. Best effort. */
export async function revokeSession(ctx: ApiHeaders) {
  await fetch(`${apiBase()}/v1/sessions/current`, { method: 'DELETE', headers: headers(ctx) }).catch(
    () => null,
  )
}

export async function googleOauthStatus() {
  const res = await fetch(`${apiBase()}/v1/oauth/google/status`, {
    headers: { Accept: 'application/json' },
  })
  if (!res.ok) return { configured: false as const }
  return json<{ configured: boolean; scopes: string[]; redirect_uri: string | null }>(
    res,
    'google oauth status',
  )
}

/** Browser navigates here; Rails redirects to Google then back to WEB_ORIGIN. */
export function googleOauthStartHref(input: { slug?: string; organizationId?: string; returnTo?: string }) {
  const url = new URL(`${apiBase()}/v1/oauth/google`)
  if (input.organizationId) url.searchParams.set('organization_id', input.organizationId)
  if (input.slug) url.searchParams.set('slug', input.slug)
  if (input.returnTo) url.searchParams.set('return_to', input.returnTo)
  return url.toString()
}

export type ConfigPlan = {
  id: string
  status: string
  manifest_hash?: string
  change_set?: Array<Record<string, unknown>>
  desired_manifest?: unknown
  created_at?: string
}

export type Affiliation = {
  id: string
  person_id: string
  company_id: string
  title?: string | null
  current?: boolean
  company?: Pick<Company, 'id' | 'name' | 'domain'> | null
  person?: { id: string; display_name?: string | null } | null
}

export type CompliancePolicy = {
  id: string
  key: string
  name: string
  priority: number
  is_fallback: boolean
  blocks?: unknown
  requirements?: unknown
}

export type ScreeningQuestion = {
  id: string
  key: string
  label: string
  field_type: string
  required?: boolean
  options?: Array<{ key: string; label: string } | string>
}

export type ApplicationFormPayload = {
  required_fields: string[]
  standard_fields: string[]
  screening_questions: ScreeningQuestion[]
  posting_questions?: ScreeningQuestion[]
}

export type CareersPage = {
  organization: { id: string; name: string; slug: string }
  careers: {
    hero_image_url: string
    headline: string
    subcopy: string
    culture?: Array<{ title: string; body: string }>
    /** Optional titled sections above the roles. */
    about?: { title: string; body: string } | null
    culture_intro?: { title: string; body: string } | null
    /** Employer accent (#RRGGBB) for the public careers page; null keeps the app accent. */
    accent_color?: string | null
    demo?: boolean
    /** False on a lab sandbox unless the deployment allows candidate applications. */
    accepts_applications?: boolean
  }
  application_form?: ApplicationFormPayload
  jobs: Array<
    Job & {
      posting_id?: string | null
      job_title?: string
      application_form?: ApplicationFormPayload
      department?: string | null
      location?: string | null
      employment_type?: string | null
      description?: string | null
    }
  >
}

export async function listConfigPlans(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/config/plans`, { headers: headers(ctx) })
  return json<{ data: ConfigPlan[] }>(res, 'config plans')
}

export async function createConfigPlan(ctx: ApiHeaders, documents: Array<Record<string, unknown>>) {
  const res = await fetch(`${apiBase()}/v1/config/plans`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('config-plan') }),
    body: JSON.stringify({ documents }),
  })
  return json<ConfigPlan>(res, 'create config plan')
}

export async function applyConfigPlan(ctx: ApiHeaders, planId: string) {
  const res = await fetch(`${apiBase()}/v1/config/apply`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('config-apply') }),
    body: JSON.stringify({ plan_id: planId }),
  })
  return json<{ plan: ConfigPlan; applied: unknown }>(res, 'apply config')
}

export async function listAffiliations(ctx: ApiHeaders, personId?: string, companyId?: string) {
  const url = new URL(`${apiBase()}/v1/affiliations`)
  if (personId) url.searchParams.set('person_id', personId)
  if (companyId) url.searchParams.set('company_id', companyId)
  const res = await fetch(url, { headers: headers(ctx) })
  return json<{ data: Affiliation[] }>(res, 'affiliations')
}

export async function createAffiliation(
  ctx: ApiHeaders,
  affiliation: { person_id: string; company_id: string; title?: string; current?: boolean },
) {
  const res = await fetch(`${apiBase()}/v1/affiliations`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('affiliation') }),
    body: JSON.stringify({ affiliation }),
  })
  return json<Affiliation>(res, 'create affiliation')
}

export async function listCompliancePolicies(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/compliance_policies`, { headers: headers(ctx) })
  return json<{ data: CompliancePolicy[] }>(res, 'compliance policies')
}

export async function erasePerson(ctx: ApiHeaders, personId: string, mode = 'delete') {
  const res = await fetch(`${apiBase()}/v1/people/${personId}/erase`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('erase') }),
    body: JSON.stringify({ mode }),
  })
  return json<{ id: string; erased: boolean; verify: string[] }>(res, 'erase person')
}

export async function submitPublicApplication(
  slug: string,
  postingId: string,
  body: Record<string, unknown>,
) {
  const res = await fetch(
    `${apiBase()}/v1/public/careers/${encodeURIComponent(slug)}/apply/${encodeURIComponent(postingId)}`,
    {
      method: 'POST',
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    },
  )
  return json<{ application_id: string; person_id: string; posting_id: string }>(res, 'public apply')
}

export async function getInternalCareers(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/internal/careers`, { headers: headers(ctx) })
  return json<CareersPage>(res, 'internal careers')
}

export async function submitInternalApplication(
  ctx: ApiHeaders,
  postingId: string,
  body: Record<string, unknown>,
) {
  const res = await fetch(`${apiBase()}/v1/internal/careers/apply/${encodeURIComponent(postingId)}`, {
    method: 'POST',
    headers: headers(ctx),
    body: JSON.stringify(body),
  })
  return json<{ application_id: string }>(res, 'internal apply')
}

export async function getPublicCareers(slug: string) {
  const res = await fetch(`${apiBase()}/v1/public/careers/${encodeURIComponent(slug)}`, {
    headers: { Accept: 'application/json' },
  })
  return json<CareersPage>(res, 'careers')
}

export async function updateOrganizationCareers(
  ctx: ApiHeaders,
  organizationId: string,
  careers: Partial<{
    careers_hero_image_url: string
    careers_headline: string
    careers_subcopy: string
  }>,
) {
  const res = await fetch(`${apiBase()}/v1/organizations/${organizationId}`, {
    method: 'PATCH',
    headers: headers(ctx),
    body: JSON.stringify({ organization: careers }),
  })
  return json<{
    id: string
    careers: CareersPage['careers']
  }>(res, 'update org careers')
}

export async function getPublicOffer(token: string) {
  const res = await fetch(`${apiBase()}/v1/public/offers/${encodeURIComponent(token)}`, {
    headers: { Accept: 'application/json' },
  })
  return json<{
    status: string
    letter_html?: string
    usable: boolean
    expires_at?: string
    organization?: { name: string; slug?: string }
    demo?: boolean
    can_accept?: boolean
    can_decline?: boolean
  }>(res, 'offer')
}

export async function acceptPublicOffer(token: string, typedName: string) {
  const res = await fetch(`${apiBase()}/v1/public/offers/${encodeURIComponent(token)}/accept`, {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify({ typed_name: typedName }),
  })
  return json<{ status: string; hired: boolean }>(res, 'accept')
}

export async function getPublicUnsubscribe(token: string) {
  const res = await fetch(`${apiBase()}/v1/public/unsubscribe/${encodeURIComponent(token)}`, {
    headers: { Accept: 'application/json' },
  })
  return json<{
    organization: { name: string }
    email_hint: string
    already_unsubscribed: boolean
  }>(res, 'unsubscribe')
}

export async function confirmPublicUnsubscribe(token: string) {
  const res = await fetch(`${apiBase()}/v1/public/unsubscribe/${encodeURIComponent(token)}`, {
    method: 'POST',
    headers: { Accept: 'application/json' },
  })
  return json<{ unsubscribed: boolean }>(res, 'unsubscribe')
}

/** Local tooling only: a token from BIGBUCK_TOKEN when nobody is signed in. */
export function sessionFromEnv(): ApiHeaders | null {
  const token = process.env.BIGBUCK_TOKEN
  if (!token) return null
  return { token }
}

/**
 * Credentials for the request being handled, from the signed session cookie.
 * The URL argument is ignored: identity never comes from query strings.
 */
export function sessionFromRequest(_url?: URL): ApiHeaders | null {
  const current = signedIn()
  if (!current) return null
  return { token: current.token, actingAgentId: current.actingAgentId }
}

// --- Identity: agents and credentials (REST; tokens are shown once) ---

export type AgentRecord = {
  id: string
  name: string
  description?: string | null
  status: 'active' | 'paused' | 'revoked'
  scopes: string[]
  owner_membership_id: string
  version: number
}

export type CredentialRecord = {
  id: string
  kind: 'personal' | 'integration' | 'agent' | 'session'
  name: string
  token_prefix: string
  scopes: string[]
  agent_id?: string | null
  status: string
  expires_at?: string | null
  last_used_at?: string | null
  token?: string
}

async function problem(res: Response, label: string): Promise<never> {
  let detail = ''
  try {
    const body = (await res.json()) as { title?: string; code?: string }
    detail = body.title ?? body.code ?? ''
  } catch {
    // not JSON
  }
  throw new Error(detail ? `${label}: ${detail}` : `${label} ${res.status}`)
}

export async function listAgents(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/agents`, { headers: headers(ctx) })
  if (!res.ok) return problem(res, 'agents')
  return (await res.json()) as { data: AgentRecord[] }
}

export async function createAgent(
  ctx: ApiHeaders,
  agent: { name: string; description?: string; scopes: string[] },
) {
  const res = await fetch(`${apiBase()}/v1/agents`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('agent') }),
    body: JSON.stringify({ agent }),
  })
  if (!res.ok) return problem(res, 'create agent')
  return (await res.json()) as AgentRecord
}

export async function agentCommand(ctx: ApiHeaders, id: string, command: 'pause' | 'resume' | 'revoke') {
  const res = await fetch(`${apiBase()}/v1/agents/${encodeURIComponent(id)}/${command}`, {
    method: 'POST',
    headers: headers(ctx),
  })
  if (!res.ok) return problem(res, `${command} agent`)
  return (await res.json()) as AgentRecord
}

export async function issueAgentToken(ctx: ApiHeaders, id: string, name?: string) {
  const res = await fetch(`${apiBase()}/v1/agents/${encodeURIComponent(id)}/credentials`, {
    method: 'POST',
    headers: headers(ctx),
    body: JSON.stringify({ name }),
  })
  if (!res.ok) return problem(res, 'issue agent token')
  return (await res.json()) as CredentialRecord
}

export async function listCredentials(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/credentials`, { headers: headers(ctx) })
  if (!res.ok) return problem(res, 'credentials')
  return (await res.json()) as { data: CredentialRecord[] }
}

export async function createPersonalToken(
  ctx: ApiHeaders,
  input: { name: string; scopes: string[]; expires_at?: string },
) {
  const res = await fetch(`${apiBase()}/v1/credentials`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('cred') }),
    body: JSON.stringify({ kind: 'personal', ...input }),
  })
  if (!res.ok) return problem(res, 'create token')
  return (await res.json()) as CredentialRecord
}

export async function revokeCredential(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/credentials/${encodeURIComponent(id)}/revoke`, {
    method: 'POST',
    headers: headers(ctx),
  })
  if (!res.ok) return problem(res, 'revoke token')
  return (await res.json()) as CredentialRecord
}

export type Communication = {
  id: string
  person_id: string
  direction: string
  channel: string
  subject?: string | null
  body?: string | null
  status: string
  message_type?: string | null
  created_at?: string
}

export async function listCommunications(ctx: ApiHeaders, personId: string) {
  const res = await fetch(`${apiBase()}/v1/people/${encodeURIComponent(personId)}/communications`, {
    headers: headers(ctx),
  })
  return json<{ data: Communication[] }>(res, 'communications')
}

export type SavedSearch = {
  id: string
  name: string
  entity_type: string
  filters: Record<string, string>
}

/** What a recruiter may relabel a reply as. A bounce is set by the mail system, never by hand. */
export const REPLY_LABELS = [
  'interested',
  'question',
  'not_interested',
  'unsubscribe',
  'out_of_office',
  'other',
] as const

/** Corrects how a reply was classified. Marking it "unsubscribe" also opts the person out. */
export async function classifyReply(ctx: ApiHeaders, communicationId: string, classification: string) {
  const res = await fetch(`${apiBase()}/v1/communications/${encodeURIComponent(communicationId)}`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('classify') }),
    body: JSON.stringify({ communication: { classification } }),
  })
  return json<{ id: string; classification: string }>(res, 'classify reply')
}

export async function listSavedSearches(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/saved_searches`, { headers: headers(ctx) })
  return json<{ data: SavedSearch[] }>(res, 'saved searches')
}

export async function createSavedSearch(
  ctx: ApiHeaders,
  saved: { name: string; filters: Record<string, string> },
) {
  const res = await fetch(`${apiBase()}/v1/saved_searches`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('search') }),
    body: JSON.stringify({
      saved_search: { name: saved.name, entity_type: 'person', filters: saved.filters },
    }),
  })
  return json<SavedSearch>(res, 'save search')
}

export async function deleteSavedSearch(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/saved_searches/${encodeURIComponent(id)}`, {
    method: 'DELETE',
    headers: headers(ctx),
  })
  if (!res.ok) throw new Error(`delete search ${res.status}`)
}

export type MessageTemplate = {
  id: string
  key: string
  name?: string | null
  subject?: string | null
  body?: string | null
  message_type?: string | null
  status?: string
  locale?: string | null
}

export async function listMessageTemplates(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/message_templates`, { headers: headers(ctx) })
  return json<{ data: MessageTemplate[] }>(res, 'templates')
}

export async function createMessageTemplate(
  ctx: ApiHeaders,
  template: { key: string; subject: string; body: string; message_type?: string },
) {
  const res = await fetch(`${apiBase()}/v1/message_templates`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('template') }),
    body: JSON.stringify({ message_template: template }),
  })
  return json<MessageTemplate>(res, 'create template')
}

export async function updateMessageTemplate(
  ctx: ApiHeaders,
  id: string,
  template: { subject: string; body: string },
) {
  const res = await fetch(`${apiBase()}/v1/message_templates/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('template-update') }),
    body: JSON.stringify({ message_template: template }),
  })
  return json<MessageTemplate>(res, 'update template')
}

export async function archiveMessageTemplate(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/message_templates/${encodeURIComponent(id)}/archive`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('template-archive') }),
  })
  return json<MessageTemplate>(res, 'archive template')
}

export async function getApplicationForm(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/application_form`, { headers: headers(ctx) })
  return json<ApplicationFormPayload>(res, 'application form')
}

export async function updateApplicationForm(
  ctx: ApiHeaders,
  form: { required_fields: string[]; screening_field_ids?: string[] },
) {
  const res = await fetch(`${apiBase()}/v1/application_form`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('form') }),
    body: JSON.stringify({ application_form: form }),
  })
  return json<ApplicationFormPayload>(res, 'update application form')
}

export type CalendarConnection = {
  id: string
  calendar_id?: string | null
  kind?: string | null
  status?: string | null
  user_id?: string | null
}

export async function listCalendarConnections(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/calendar_connections`, { headers: headers(ctx) })
  return json<{ data: CalendarConnection[] }>(res, 'calendars')
}

export async function createCalendarConnection(
  ctx: ApiHeaders,
  connection: { calendar_id: string; secret_ref: string; kind?: string },
) {
  const res = await fetch(`${apiBase()}/v1/calendar_connections`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('calendar') }),
    body: JSON.stringify({ calendar_connection: connection }),
  })
  return json<CalendarConnection>(res, 'connect calendar')
}

export type ImportRun = {
  id: string
  status: string
  entity?: string
  row_count?: number
  created_count?: number
  error_count?: number
  created_at?: string
}

export async function listImports(ctx: ApiHeaders) {
  const res = await fetch(`${apiBase()}/v1/imports`, { headers: headers(ctx) })
  return json<{ data: ImportRun[] }>(res, 'imports')
}

export async function createImport(ctx: ApiHeaders, input: { csv: string; dry_run?: boolean }) {
  const res = await fetch(`${apiBase()}/v1/imports`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('import') }),
    body: JSON.stringify({ import: { entity: 'people', csv: input.csv, dry_run: input.dry_run ?? true } }),
  })
  return json<ImportRun>(res, 'import')
}

export type DemoMembership = {
  email: string
  name: string
  role_key: string
  role_name: string
}

export async function listDemoMemberships(slug: string) {
  const url = new URL(`${apiBase()}/v1/sessions/demo_memberships`)
  if (slug) url.searchParams.set('slug', slug)
  const res = await fetch(url, { headers: { Accept: 'application/json' } })
  return json<{ data: DemoMembership[] }>(res, 'demo memberships')
}

export type PostingQuestion = {
  key: string
  label: string
  field_type: string
  required?: boolean
  options?: string[]
}
export type JobPosting = {
  id: string
  job_id: string
  title: string
  description?: string | null
  location?: string | null
  employment_type?: string | null
  status: string
  audience: CareersVisibility
  version: number
  questions: PostingQuestion[]
  template_questions: PostingQuestion[]
  question_template_id?: string | null
  template_version?: number | null
  application_form?: ApplicationFormPayload
}
export type QuestionTemplate = {
  id: string
  name: string
  status: string
  owner_user_id: string
  owner_name: string
  version: number
  can_edit: boolean
  questions: PostingQuestion[]
}
export async function listJobPostings(ctx: ApiHeaders, jobId: string) {
  return json<{ data: JobPosting[]; application_form: ApplicationFormPayload }>(
    await fetch(`${apiBase()}/v1/jobs/${encodeURIComponent(jobId)}/postings`, { headers: headers(ctx) }),
    'postings',
  )
}
export async function saveJobPosting(
  ctx: ApiHeaders,
  jobId: string,
  postingId: string | null,
  posting: Record<string, unknown>,
) {
  const path = postingId
    ? `/v1/postings/${encodeURIComponent(postingId)}`
    : `/v1/jobs/${encodeURIComponent(jobId)}/postings`
  return json<JobPosting>(
    await fetch(`${apiBase()}${path}`, {
      method: postingId ? 'PATCH' : 'POST',
      headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('posting') }),
      body: JSON.stringify({ posting }),
    }),
    'save posting',
  )
}
export async function listQuestionTemplates(ctx: ApiHeaders) {
  return json<{ data: QuestionTemplate[] }>(
    await fetch(`${apiBase()}/v1/application_question_templates`, { headers: headers(ctx) }),
    'question templates',
  )
}
export async function saveQuestionTemplate(
  ctx: ApiHeaders,
  templateId: string | null,
  question_template: Record<string, unknown>,
) {
  return json<QuestionTemplate>(
    await fetch(
      `${apiBase()}/v1/application_question_templates${templateId ? `/${encodeURIComponent(templateId)}` : ''}`,
      {
        method: templateId ? 'PATCH' : 'POST',
        headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('question-template') }),
        body: JSON.stringify({ question_template }),
      },
    ),
    'save question template',
  )
}

export type AgentProposal = {
  id: string
  agent_id: string
  kind: string
  job_id?: string | null
  person_id: string
  sequence_id?: string | null
  status: 'pending' | 'approved' | 'rejected'
  draft_opener?: string | null
  final_opener?: string | null
  rationale?: Record<string, unknown> | string | null
  decision_reason?: string | null
  decided_at?: string | null
  enrollment_id?: string | null
  created_at: string
  person?: { id: string; display_name: string; primary_email?: string | null } | null
  agent?: { id: string; name?: string | null } | null
}

export async function listAgentProposals(ctx: ApiHeaders, query: Record<string, string> = {}) {
  const qs = new URLSearchParams(query).toString()
  const res = await fetch(`${apiBase()}/v1/agent_proposals${qs ? `?${qs}` : ''}`, { headers: headers(ctx) })
  return json<{ data: AgentProposal[]; meta?: { statuses?: Record<string, number> } }>(res, 'proposals')
}

export async function decideAgentProposal(
  ctx: ApiHeaders,
  id: string,
  decision: 'approve' | 'reject',
  body: { opener?: string; reason?: string } = {},
) {
  const res = await fetch(`${apiBase()}/v1/agent_proposals/${encodeURIComponent(id)}/${decision}`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('proposal') }),
    body: JSON.stringify(body),
  })
  return json<AgentProposal>(res, `${decision} proposal`)
}

export async function bulkApproveProposals(ctx: ApiHeaders, ids: string[]) {
  const res = await fetch(`${apiBase()}/v1/agent_proposals/bulk_approve`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('proposal') }),
    body: JSON.stringify({ ids }),
  })
  return json<{ approved: number; failed: number }>(res, 'approve proposals')
}

export async function runSourcingAgent(
  ctx: ApiHeaders,
  jobId: string,
  body: { sequence_id: string; mailbox_id?: string; limit?: number },
) {
  const res = await fetch(`${apiBase()}/v1/jobs/${encodeURIComponent(jobId)}/sourcing_agent/run`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('sourcing') }),
    body: JSON.stringify(body),
  })
  return json<{ proposed: string[]; auto_enrolled: number; skipped: Record<string, number> }>(
    res,
    'run sourcing agent',
  )
}

export type RediscoveryCriterion = {
  id: string
  label: string
  kind: 'must' | 'nice'
  match: Record<string, string>
}

export type RediscoveryCandidate = {
  id: string
  job_id: string
  person_id: string
  status: string
  bucket: string
  score: number
  reasons?: string[] | null
  feedback?: string | null
  person?: { id: string; display_name: string; primary_email?: string | null } | null
}

export async function getRediscoveryCriteria(ctx: ApiHeaders, jobId: string) {
  const res = await fetch(`${apiBase()}/v1/jobs/${encodeURIComponent(jobId)}/rediscovery/criteria`, {
    headers: headers(ctx),
  })
  return json<{ criteria: RediscoveryCriterion[] }>(res, 'rediscovery criteria')
}

export async function saveRediscoveryCriteria(
  ctx: ApiHeaders,
  jobId: string,
  criteria: Array<Omit<RediscoveryCriterion, 'id'> & { id?: string }>,
) {
  const res = await fetch(`${apiBase()}/v1/jobs/${encodeURIComponent(jobId)}/rediscovery/criteria`, {
    method: 'PUT',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('criteria') }),
    body: JSON.stringify({ criteria }),
  })
  return json<{ criteria: RediscoveryCriterion[] }>(res, 'save criteria')
}

export async function runRediscovery(ctx: ApiHeaders, jobId: string) {
  const res = await fetch(`${apiBase()}/v1/jobs/${encodeURIComponent(jobId)}/rediscovery/run`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('rediscovery') }),
    body: '{}',
  })
  return json<{ created: number; refreshed: number; buckets: Record<string, number> }>(res, 'run rediscovery')
}

export async function listRediscoveryQueue(
  ctx: ApiHeaders,
  jobId: string,
  query: Record<string, string> = {},
) {
  const qs = new URLSearchParams(query).toString()
  const res = await fetch(
    `${apiBase()}/v1/jobs/${encodeURIComponent(jobId)}/rediscovery/queue${qs ? `?${qs}` : ''}`,
    { headers: headers(ctx) },
  )
  return json<{
    data: RediscoveryCandidate[]
    meta?: { buckets?: Record<string, number>; statuses?: Record<string, number> }
  }>(res, 'rediscovery queue')
}

export async function reviewRediscoveryCandidate(
  ctx: ApiHeaders,
  id: string,
  body: { review_action: string; sequence_id?: string; feedback?: string },
) {
  const res = await fetch(`${apiBase()}/v1/rediscovery_candidates/${encodeURIComponent(id)}/review`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('review') }),
    body: JSON.stringify(body),
  })
  return json<RediscoveryCandidate>(res, 'review candidate')
}

export type EnrollmentPlan = {
  sequence_id: string
  mailbox_id: string
  counts: Record<string, number>
  will_enroll: Array<{ id: string; display_name: string; primary_email?: string | null }>
  skipped: Array<{ id: string; display_name: string; primary_email?: string | null; reason: string }>
  first_send_at?: string | null
}

export async function planEnrollment(
  ctx: ApiHeaders,
  sequenceId: string,
  body: { project_id?: string; saved_search_id?: string; person_ids?: string[]; mailbox_id?: string },
) {
  const res = await fetch(`${apiBase()}/v1/sequences/${encodeURIComponent(sequenceId)}/enrollment_plan`, {
    method: 'POST',
    headers: headers(ctx),
    body: JSON.stringify(body),
  })
  return json<EnrollmentPlan>(res, 'enrollment plan')
}

export async function enrollPlanned(
  ctx: ApiHeaders,
  sequenceId: string,
  body: { person_ids: string[]; mailbox_id?: string },
) {
  const res = await fetch(`${apiBase()}/v1/sequences/${encodeURIComponent(sequenceId)}/enroll_planned`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('enroll') }),
    body: JSON.stringify(body),
  })
  return json<{ enrolled: number; failed: number; skipped: number }>(res, 'enroll people')
}

export type PoolAddResult = { added: number; already_members: number }

export async function addPeopleToPool(
  ctx: ApiHeaders,
  projectId: string,
  body: { saved_search_id?: string; person_ids?: string[] },
) {
  const res = await fetch(`${apiBase()}/v1/projects/${encodeURIComponent(projectId)}/people`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('pool') }),
    body: JSON.stringify(body),
  })
  return json<PoolAddResult>(res, 'add people to pool')
}

/** Moves many pool members to one stage; members already there are moved to the same stage again (a no-op). */
export async function bulkMovePoolMembers(
  ctx: ApiHeaders,
  projectId: string,
  body: { member_ids: string[]; to_stage_key: string; reason?: string },
) {
  const res = await fetch(`${apiBase()}/v1/projects/${encodeURIComponent(projectId)}/transitions`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('pool-move') }),
    body: JSON.stringify(body),
  })
  return json<{ moved: number }>(res, 'move pool members')
}

export async function addPoolPeopleFromJob(ctx: ApiHeaders, projectId: string, jobId: string) {
  const res = await fetch(`${apiBase()}/v1/projects/${encodeURIComponent(projectId)}/from_job`, {
    method: 'POST',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('pool') }),
    body: JSON.stringify({ job_id: jobId }),
  })
  return json<PoolAddResult>(res, 'add applicants to pool')
}

export type SequenceStepStats = {
  id: string
  type: string
  messages: Record<string, number>
  replies: number
}

export async function getSequenceStats(ctx: ApiHeaders, id: string) {
  const res = await fetch(`${apiBase()}/v1/sequences/${encodeURIComponent(id)}/stats`, {
    headers: headers(ctx),
  })
  return json<{ enrolled: number; active: number; steps: SequenceStepStats[] }>(res, 'sequence stats')
}

export async function updateSequenceSteps(
  ctx: ApiHeaders,
  id: string,
  steps: Array<Record<string, unknown>>,
) {
  const res = await fetch(`${apiBase()}/v1/sequences/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: headers(ctx, { 'Idempotency-Key': idempotencyKey('sequence') }),
    body: JSON.stringify({ sequence: { steps } }),
  })
  return json<Sequence>(res, 'update sequence steps')
}

export type SequencePreviewStep = {
  index: number
  type: string
  subject?: string | null
  body?: string | null
  missing_template?: boolean
}

export async function previewSequence(ctx: ApiHeaders, id: string, personId: string) {
  const res = await fetch(
    `${apiBase()}/v1/sequences/${encodeURIComponent(id)}/preview?person_id=${encodeURIComponent(personId)}`,
    { headers: headers(ctx) },
  )
  return json<{ steps: SequencePreviewStep[] }>(res, 'preview sequence')
}
