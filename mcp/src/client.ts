import { randomUUID } from 'node:crypto'

export type ApiConfig = {
  demoGeneration?: number
  baseUrl: string
  /** Agent (or personal) bearer token: `bb_live_…`. Create one with POST /v1/agents/{id}/credentials. */
  token?: string
  /** Legacy local-dev header harness only (Rails BIGBUCK_ALLOW_HEADER_AUTH=1). Ignored when token is set. */
  organizationId?: string
  actorId?: string
  allowWrites: boolean
}

export function configFromEnv(): ApiConfig {
  const token = process.env.BIGBUCK_TOKEN
  const organizationId = process.env.BIGBUCK_ORG_ID ?? process.env.X_ORGANIZATION_ID
  if (!token && !organizationId) {
    throw new Error('BIGBUCK_TOKEN is required (an agent token from POST /v1/agents/{id}/credentials)')
  }
  return {
    demoGeneration: process.env.BIGBUCK_DEMO_GENERATION ? Number(process.env.BIGBUCK_DEMO_GENERATION) : undefined,
    baseUrl: (process.env.BIGBUCK_API_URL ?? process.env.RAILS_API_URL ?? 'http://127.0.0.1:3000').replace(
      /\/$/,
      '',
    ),
    token,
    organizationId,
    actorId: process.env.BIGBUCK_ACTOR_ID ?? process.env.X_ACTOR_ID,
    allowWrites: ['1', 'true', 'yes'].includes(
      (process.env.BIGBUCK_MCP_ALLOW_WRITES ?? '').toLowerCase(),
    ),
  }
}

export function authHeaders(cfg: ApiConfig): Record<string, string> {
  const headers: Record<string, string> = { 'X-Bigbuck-Surface': 'mcp',
    ...(cfg.demoGeneration ? { 'X-Bigbuck-Demo-Generation': String(cfg.demoGeneration) } : {}) }
  if (cfg.token) {
    headers.Authorization = `Bearer ${cfg.token}`
  } else if (cfg.organizationId) {
    headers['X-Organization-Id'] = cfg.organizationId
    headers['X-Actor-Type'] = 'agent'
    if (cfg.actorId) headers['X-Actor-Id'] = cfg.actorId
  }
  return headers
}

export async function callApi(
  cfg: ApiConfig,
  method: string,
  pathTemplate: string,
  args: Record<string, unknown>,
  opts: { write: boolean; hasJsonBody: boolean },
): Promise<{ status: number; body: unknown }> {
  if (opts.write && !cfg.allowWrites) {
    throw new Error(
      'Write tools are disabled. Set BIGBUCK_MCP_ALLOW_WRITES=true to enable mutating API calls.',
    )
  }

  const pathArgs = { ...args }
  const query = new URLSearchParams()
  let path = pathTemplate
  for (const [key, value] of Object.entries(args)) {
    const token = `{${key}}`
    if (path.includes(token)) {
      path = path.replaceAll(token, encodeURIComponent(String(value)))
      delete pathArgs[key]
    }
  }

  // Remaining scalar args without body go to query for GET; body for writes.
  const bodyKeys = new Set(Object.keys(pathArgs))
  let body: unknown = undefined
  if (opts.hasJsonBody && method.toUpperCase() !== 'GET') {
    body = pathArgs.body ?? pathArgs
    if (pathArgs.body !== undefined) {
      body = pathArgs.body
      bodyKeys.delete('body')
    }
  } else {
    for (const [key, value] of Object.entries(pathArgs)) {
      if (value === undefined || value === null) continue
      if (typeof value === 'object') continue
      query.set(key, String(value))
    }
  }

  const url = new URL(`${cfg.baseUrl}/v1${path}`)
  for (const [k, v] of query) url.searchParams.set(k, v)

  const headers: Record<string, string> = {
    Accept: 'application/json',
    ...authHeaders(cfg),
  }
  if (opts.write) headers['Idempotency-Key'] = `mcp-${randomUUID()}`
  if (body !== undefined) headers['Content-Type'] = 'application/json'

  const res = await fetch(url, {
    method: method.toUpperCase(),
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  })
  const text = await res.text()
  let parsed: unknown = text
  try {
    parsed = text ? JSON.parse(text) : null
  } catch {
    parsed = text
  }
  return { status: res.status, body: parsed }
}
