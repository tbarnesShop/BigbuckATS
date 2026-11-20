import { randomUUID } from 'node:crypto'

import { CURATED_TOOLS, findCuratedTool, type CuratedGraphqlTool } from './curated-graphql.js'
import { BigBuckApiError, type ProblemBody } from './errors.js'
import { findOperation, loadOperations, type OpenApiOperation } from './openapi.js'
import type { ClientOptions, ConfigDocument, ImportCreateInput, RequestOptions } from './types.js'

export class BigBuckClient {
  readonly demoGeneration?: number
  readonly baseUrl: string
  readonly token?: string
  private readonly tokenProvider?: () => Promise<string>
  readonly organizationId?: string
  readonly actorId?: string
  readonly actorType: string
  readonly actAsAgentId?: string
  private readonly fetchImpl: typeof fetch

  constructor(opts: ClientOptions) {
    if (!opts.token && !opts.tokenProvider && !opts.organizationId) throw new Error('token is required (or organizationId for the local header harness)')
    this.demoGeneration = opts.demoGeneration
    this.baseUrl = (opts.baseUrl ?? process.env.BIGBUCK_API_URL ?? 'http://127.0.0.1:3000').replace(
      /\/$/,
      '',
    )
    this.token = opts.token
    this.tokenProvider = opts.tokenProvider
    this.organizationId = opts.organizationId
    this.actorId = opts.actorId
    this.actorType = opts.actorType ?? 'cli'
    this.actAsAgentId = opts.actAsAgentId
    this.fetchImpl = opts.fetch ?? fetch
  }

  static fromEnv(overrides: Partial<ClientOptions> = {}): BigBuckClient {
    const token = overrides.token ?? process.env.BIGBUCK_TOKEN
    const organizationId =
      overrides.organizationId ?? process.env.BIGBUCK_ORG_ID ?? process.env.X_ORGANIZATION_ID
    if (!token && !overrides.tokenProvider && !organizationId) {
      throw new Error('BIGBUCK_TOKEN is required')
    }
    return new BigBuckClient({
      baseUrl: overrides.baseUrl ?? process.env.BIGBUCK_API_URL ?? process.env.RAILS_API_URL,
      token,
      tokenProvider: overrides.tokenProvider,
      organizationId,
      actorId: overrides.actorId ?? process.env.BIGBUCK_ACTOR_ID ?? process.env.X_ACTOR_ID,
      actorType: overrides.actorType ?? 'cli',
      actAsAgentId: overrides.actAsAgentId ?? process.env.BIGBUCK_ACT_AS_AGENT,
      demoGeneration: overrides.demoGeneration ?? (process.env.BIGBUCK_DEMO_GENERATION ? Number(process.env.BIGBUCK_DEMO_GENERATION):undefined),
      fetch: overrides.fetch,
    })
  }

  /** Auth headers shared by REST `/v1` and GraphQL `/graphql`. */
  private async authHeaders(skipOrg = false): Promise<Record<string, string>> {
    const headers: Record<string, string> = {
      Accept: 'application/json',
      'X-Bigbuck-Surface': this.actorType,
      ...(this.demoGeneration ? { 'X-Bigbuck-Demo-Generation': String(this.demoGeneration) } : {}),
    }
    const token = this.tokenProvider ? await this.tokenProvider() : this.token
    if (this.tokenProvider && (!token || typeof token !== 'string')) {
      throw new Error('OAuth token provider returned an empty token')
    }
    if (token) {
      headers.Authorization = `Bearer ${token}`
      if (this.actAsAgentId) headers['X-Bigbuck-Act-As-Agent'] = this.actAsAgentId
    } else {
      headers['X-Actor-Type'] = this.actorType
      if (!skipOrg && this.organizationId) headers['X-Organization-Id'] = this.organizationId
      if (this.actorId) headers['X-Actor-Id'] = this.actorId
    }
    return headers
  }

  async request<T = unknown>(opts: RequestOptions): Promise<T> {
    const method = (opts.method ?? 'GET').toUpperCase()
    const url = new URL(`${this.baseUrl}/v1${opts.path}`)
    for (const [key, value] of Object.entries(opts.query ?? {})) {
      if (value === undefined || value === null) continue
      url.searchParams.set(key, String(value))
    }

    const headers = await this.authHeaders(opts.skipOrg)
    const write = !['GET', 'HEAD'].includes(method)
    if (write) {
      headers['Idempotency-Key'] = opts.idempotencyKey ?? `sdk-${randomUUID()}`
    }
    if (opts.body !== undefined) headers['Content-Type'] = 'application/json'

    const res = await this.fetchImpl(url, {
      method,
      redirect: 'error',
      headers,
      body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
    })

    const text = await res.text()
    let parsed: unknown = text ? text : null
    if (text) {
      try {
        parsed = JSON.parse(text)
      } catch {
        parsed = text
      }
    }

    if (!res.ok) {
      const problem =
        parsed && typeof parsed === 'object'
          ? (parsed as ProblemBody)
          : { title: String(parsed), status: res.status }
      throw new BigBuckApiError(res.status, problem)
    }

    return parsed as T
  }

  // --- OpenAPI catalog (same contract as MCP REST tools) ---

  listOperations(): OpenApiOperation[] {
    return loadOperations()
  }

  listCuratedGraphqlTools(): CuratedGraphqlTool[] {
    return CURATED_TOOLS
  }

  /**
   * Run a GraphQL document against `/graphql` (same endpoint as the web app and MCP).
   * Returns the JSON body; callers should inspect `errors` / `userErrors`.
   */
  async graphql<T = unknown>(
    document: string,
    variables: Record<string, unknown> = {},
  ): Promise<T> {
    const headers = await this.authHeaders()
    headers['Content-Type'] = 'application/json'
    const res = await this.fetchImpl(`${this.baseUrl}/graphql`, {
      method: 'POST',
      redirect: 'error',
      headers,
      body: JSON.stringify({ query: document, variables }),
    })
    const text = await res.text()
    let parsed: unknown = text ? text : null
    if (text) {
      try {
        parsed = JSON.parse(text)
      } catch {
        parsed = text
      }
    }
    if (!res.ok) {
      const problem =
        parsed && typeof parsed === 'object'
          ? (parsed as ProblemBody)
          : { title: String(parsed), status: res.status }
      throw new BigBuckApiError(res.status, problem)
    }
    return parsed as T
  }

  /** Run one of the shared curated GraphQL tools (same names as MCP `gql_*`). */
  curatedGraphql<T = unknown>(name: string, variables: Record<string, unknown> = {}): Promise<T> {
    const tool = findCuratedTool(name)
    if (!tool) throw new Error(`Unknown curated GraphQL tool: ${name}`)
    const args: Record<string, unknown> = {}
    for (const [key, spec] of Object.entries(tool.variables)) {
      const value = variables[key]
      if (value === undefined || value === null || value === '') {
        if (spec.required) throw new Error(`${name} requires ${key}`)
        continue
      }
      args[key] = spec.type === 'integer' ? Number(value) : value
    }
    return this.graphql<T>(tool.document, args)
  }

  /**
   * Call any `/v1` operation by OpenAPI `operationId`.
   * Path/query args are top-level keys; JSON bodies use `body` (or the remaining object for writes).
   */
  invoke<T = unknown>(operationId: string, args: Record<string, unknown> = {}): Promise<T> {
    const operation = findOperation(operationId)
    if (!operation) throw new Error(`Unknown OpenAPI operationId: ${operationId}`)

    let path = operation.path
    const remaining: Record<string, unknown> = { ...args }
    for (const [key, value] of Object.entries(args)) {
      const token = `{${key}}`
      if (!path.includes(token)) continue
      if (value === undefined || value === null || value === '') {
        throw new Error(`${operationId} requires path parameter ${key}`)
      }
      path = path.replaceAll(token, encodeURIComponent(String(value)))
      delete remaining[key]
    }
    if (/\{/.test(path)) {
      throw new Error(`${operationId} is missing path parameters for ${path}`)
    }

    const query: Record<string, string | number | boolean | undefined | null> = {}
    let body: unknown
    if (operation.hasJsonBody && operation.method !== 'get') {
      body = remaining.body !== undefined ? remaining.body : remaining
    } else {
      for (const [key, value] of Object.entries(remaining)) {
        if (value === undefined || value === null || typeof value === 'object') continue
        query[key] = value as string | number | boolean
      }
    }

    return this.request<T>({
      method: operation.method.toUpperCase(),
      path,
      query,
      body,
      skipOrg: path === '/health' || path.startsWith('/public/') || path.startsWith('/oauth/'),
    })
  }

  // --- Platform ---

  getHealth() {
    return this.request<{ status: string; service: string }>({
      path: '/health',
      skipOrg: true,
    })
  }

  // --- People ---

  listPeople() {
    return this.request<{ data: Record<string, unknown>[] }>({ path: '/people' })
  }

  getPerson(id: string) {
    return this.request<Record<string, unknown>>({ path: `/people/${id}` })
  }

  createPerson(person: { display_name: string; email?: string; phone?: string }) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: '/people',
      body: { person },
    })
  }

  // --- Jobs ---

  listJobs() {
    return this.request<{ data: Record<string, unknown>[] }>({ path: '/jobs' })
  }

  getJob(id: string) {
    return this.request<Record<string, unknown>>({ path: `/jobs/${id}` })
  }

  createJob(job: { title: string; status?: string; pipeline_id?: string }) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: '/jobs',
      body: { job },
    })
  }

  // --- Applications ---

  listApplications(filters: { jobId?: string; personId?: string } = {}) {
    return this.request<{ data: Record<string, unknown>[] }>({
      path: '/applications',
      query: { job_id: filters.jobId, person_id: filters.personId },
    })
  }

  getApplication(id: string) {
    return this.request<Record<string, unknown>>({ path: `/applications/${id}` })
  }

  createApplication(input: { job_id: string; person_id: string; consents?: string[]; locale?: string }) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: '/applications',
      body: { application: input },
    })
  }

  moveApplication(id: string, toStageKey: string, reason?: string) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: `/applications/${id}/transitions`,
      body: { command: 'move', to_stage_key: toStageKey, reason },
    })
  }

  rejectApplication(id: string, reason: string) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: `/applications/${id}/transitions`,
      body: { command: 'reject', reason },
    })
  }

  // --- Projects (pools) ---

  listProjects() {
    return this.request<{ data: Record<string, unknown>[] }>({ path: '/projects' })
  }

  getProject(id: string) {
    return this.request<Record<string, unknown>>({ path: `/projects/${id}` })
  }

  createProject(project: { name: string; job_id?: string; pipeline_id?: string; confidential?: boolean }) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: '/projects',
      body: { project },
    })
  }

  listProjectMembers(projectId: string) {
    return this.request<{ data: Record<string, unknown>[] }>({
      path: `/projects/${projectId}/members`,
    })
  }

  addProjectMember(projectId: string, personId: string) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: `/projects/${projectId}/members`,
      body: { member: { person_id: personId } },
    })
  }

  convertProjectMember(memberId: string, jobId?: string) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: `/project_members/${memberId}/convert`,
      body: jobId ? { job_id: jobId } : {},
    })
  }

  // --- Sequences ---

  listSequences() {
    return this.request<{ data: Record<string, unknown>[] }>({ path: '/sequences' })
  }

  createSequence(sequence: { key: string; name: string; status?: string; steps?: unknown[] }) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: '/sequences',
      body: { sequence },
    })
  }

  enrollInSequence(sequenceId: string, personId: string, mailboxId?: string) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: `/sequences/${sequenceId}/enrollments`,
      body: { enrollment: { person_id: personId, mailbox_id: mailboxId } },
    })
  }

  stopEnrollment(enrollmentId: string) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: `/enrollments/${enrollmentId}/stop`,
      body: {},
    })
  }

  // --- Config as code ---

  listConfigPlans() {
    return this.request<{ data: Record<string, unknown>[] }>({ path: '/config/plans' })
  }

  createConfigPlan(documents: ConfigDocument[]) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: '/config/plans',
      body: { documents },
    })
  }

  applyConfigPlan(planId: string) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: '/config/apply',
      body: { plan_id: planId },
    })
  }

  // --- CSV import ---

  listImports() {
    return this.request<{ data: Record<string, unknown>[] }>({ path: '/imports' })
  }

  getImport(id: string) {
    return this.request<Record<string, unknown>>({ path: `/imports/${id}` })
  }

  createImport(input: ImportCreateInput) {
    return this.request<Record<string, unknown>>({
      method: 'POST',
      path: '/imports',
      body: {
        import: {
          entity: input.entity ?? 'people',
          csv: input.csv,
          dry_run: input.dryRun ?? false,
          source_system: input.sourceSystem ?? 'csv',
          field_mapping: input.fieldMapping,
        },
      },
    })
  }

  // --- Identity: sessions, agents, credentials ---

  /** Who this token acts as: user, agent, organization and effective permissions. */
  currentSession() {
    return this.request<Record<string, unknown>>({ path: '/sessions/current' })
  }

  listAgents() {
    return this.request<{ data: Record<string, unknown>[] }>({ path: '/agents' })
  }

  createAgent(agent: { name: string; scopes: string[]; description?: string }) {
    return this.request<Record<string, unknown>>({ method: 'POST', path: '/agents', body: { agent } })
  }

  /** Issues a bearer token for the agent. The token is returned once. */
  createAgentCredential(agentId: string, input: { name?: string; expires_at?: string } = {}) {
    return this.request<Record<string, unknown> & { token: string }>({
      method: 'POST',
      path: `/agents/${agentId}/credentials`,
      body: input,
    })
  }

  pauseAgent(agentId: string) {
    return this.request<Record<string, unknown>>({ method: 'POST', path: `/agents/${agentId}/pause` })
  }

  resumeAgent(agentId: string) {
    return this.request<Record<string, unknown>>({ method: 'POST', path: `/agents/${agentId}/resume` })
  }

  revokeAgent(agentId: string) {
    return this.request<Record<string, unknown>>({ method: 'POST', path: `/agents/${agentId}/revoke` })
  }
}
