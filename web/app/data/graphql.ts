import { createHash } from 'node:crypto'
import { signedIn } from './auth.ts'

import { operations, type OperationName } from '../graphql/operations.ts'
import type { ApiHeaders } from './api.ts'

/**
 * Server-side GraphQL client. Sends persisted query ids (sha256 of the
 * registered document) with the signed-in user's bearer token; falls back to
 * the document text where Rails allows it (development, agents).
 */

function apiBase(): string {
  return process.env.RAILS_API_URL ?? 'http://127.0.0.1:3000'
}

export function documentId(document: string): string {
  return createHash('sha256').update(document).digest('hex')
}

export function persistedManifest(): Record<string, string> {
  const manifest: Record<string, string> = {}
  for (const document of Object.values(operations)) manifest[documentId(document)] = document
  return Object.fromEntries(Object.entries(manifest).sort(([a], [b]) => a.localeCompare(b)))
}

export class GraphQLRequestError extends Error {
  constructor(
    message: string,
    readonly errors: Array<{ message: string; extensions?: { code?: string } }>,
  ) {
    super(message)
  }
}

export async function gql<TData, TVariables extends Record<string, unknown> = Record<string, never>>(
  ctx: ApiHeaders,
  operationName: OperationName,
  variables?: TVariables,
): Promise<TData> {
  const document = operations[operationName]
  const headers: Record<string, string> = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
    Authorization: `Bearer ${ctx.token}`,
    'X-Bigbuck-Surface': 'web',
    ...(signedIn()?.lab ? { 'X-Bigbuck-Demo-Generation': String(signedIn()!.lab!.generation) } : {}),
    ...(ctx.actingAgentId ? { 'X-Bigbuck-Act-As-Agent': ctx.actingAgentId } : {}),
  }
  const send = (body: Record<string, unknown>) =>
    fetch(`${apiBase()}/graphql`, { method: 'POST', headers, body: JSON.stringify({ operationName, variables, ...body }) })

  let res = await send({ id: documentId(document) })
  // Not registered on this API yet (e.g. local dev before persist-queries): send the text.
  if (res.status === 404) res = await send({ query: document })
  if (!res.ok) throw new GraphQLRequestError(`GraphQL ${operationName} ${res.status}`, [])

  const body = (await res.json()) as { data?: TData; errors?: GraphQLRequestError['errors'] }
  if (body.errors?.length && !body.data) {
    throw new GraphQLRequestError(body.errors.map((e) => e.message).join('; '), body.errors)
  }
  return body.data as TData
}
