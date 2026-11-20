import { randomUUID } from 'node:crypto'
import { signedIn } from '../auth.ts'
import type { Sandbox, Persona, Result, RecordLink } from './types.ts'

export const apiBase = () => (process.env.RAILS_API_URL ?? 'http://127.0.0.1:3000').replace(/\/$/, '')
export class LabError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly outcome?: 'unknown',
  ) {
    super(message)
  }
}
export async function control<T>(path: string, body?: unknown): Promise<T> {
  const response = await fetch(`${apiBase()}${path}`, {
    method: body ? 'POST' : 'GET',
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(120000),
  })
  const data = (await response.json()) as any
  if (!response.ok)
    throw new LabError(
      response.status,
      data.code ?? 'lab_unavailable',
      data.title ?? 'The lab is unavailable.',
    )
  return data as T
}
export type StartResponse = {
  sandbox: Sandbox
  organization: { id: string; slug: string }
  user: { id: string; email: string; name: string }
  role_key: string
  permissions: string[]
  session: { token: string }
  tools: { token: string; agent_token: string }
}
export type StatusResponse = { sandbox: Sandbox; roles: Persona[] }
export function requireLab() {
  const session = signedIn()
  if (!session?.lab) throw new LabError(401, 'lab_session_required', 'Choose a demo persona to start.')
  if (!session.lab.toolToken || !session.lab.agentToken)
    throw new LabError(
      409,
      'sandbox_expired',
      'This lab session has expired or its server credentials are unavailable. Choose a persona to restart.',
    )
  return { ...session, lab: session.lab }
}
export async function labRequest(
  path: string,
  options: { method?: string; body?: unknown; user?: boolean; agent?: boolean; idempotencyKey?: string } = {},
): Promise<{ status: number; body: any }> {
  if (!path.startsWith('/v1/') && path !== '/graphql' && path !== '/demo/permissions')
    throw new LabError(400, 'invalid_path', 'Choose a documented Big Buck endpoint.')
  if (path.includes('://') || path.includes('..') || path.startsWith('//'))
    throw new LabError(400, 'invalid_path', 'Invalid API path.')
  const current = requireLab()
  const method = options.method ?? 'GET'
  const { response, text } = await (async () => {
    try {
      const response = await fetch(`${apiBase()}${path}`, {
        method,
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          Authorization: `Bearer ${options.agent ? current.lab.agentToken : options.user ? current.token : current.lab.toolToken}`,
          'X-Bigbuck-Surface': current.lab.surface === 'ui' ? 'web' : current.lab.surface,
          'X-Bigbuck-Demo-Generation': String(current.lab.generation),
          ...(method !== 'GET' ? { 'Idempotency-Key': options.idempotencyKey ?? randomUUID() } : {}),
        },
        body: options.body === undefined ? undefined : JSON.stringify(options.body),
        signal: AbortSignal.timeout(20000),
      })
      const text = await response.text()
      return { response, text }
    } catch {
      throw new LabError(
        503,
        'request_outcome_unknown',
        'The API connection ended before a complete response arrived. Check the record before retrying.',
        'unknown',
      )
    }
  })()
  let body: any = text
  try {
    body = JSON.parse(text)
  } catch {
    /* retain truthful non-JSON responses */
  }
  return { status: response.status, body }
}
export function recordLinks(output: unknown): RecordLink[] {
  const links: RecordLink[] = []
  const walk = (value: any, key = '', depth = 0) => {
    if (depth > 5 || !value || typeof value !== 'object') return
    if (Array.isArray(value)) {
      value.slice(0, 10).forEach((v) => walk(v, key, depth + 1))
      return
    }
    if (typeof value.id === 'string') {
      let kind =
        value.display_name || value.displayName || key === 'person'
          ? 'people'
          : value.title && ('pipeline_id' in value || key === 'job')
            ? 'jobs'
            : value.name && ('member_count' in value || key === 'project' || key === 'pool')
              ? 'projects'
              : value.person_id && value.job_id
                ? 'applications'
                : value.application_id && value.fields
                  ? 'offers'
                  : null
      if (kind) {
        const uiPath = kind === 'projects' ? 'pools' : kind === 'offers' ? 'offers/view' : kind
        links.push({
          kind,
          id: value.id,
          label: value.display_name ?? value.displayName ?? value.title ?? value.name ?? kind,
          href: `/${uiPath}/${encodeURIComponent(value.id)}`,
        })
      }
    }
    Object.entries(value).forEach(([k, v]) => walk(v, k, depth + 1))
  }
  walk(output)
  return [...new Map(links.map((link) => [link.href, link])).values()].slice(0, 8)
}
export function result(status: number, output: unknown, start: number, request?: string): Result {
  return {
    ok: status >= 200 && status < 300,
    status,
    output,
    duration: Math.round(performance.now() - start),
    links: recordLinks(output),
    request,
  }
}
