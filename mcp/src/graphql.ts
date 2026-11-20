import { randomUUID } from 'node:crypto'

import { isGraphqlMutation } from '@bigbuck/sdk'

import { authHeaders, type ApiConfig } from './client.js'

/**
 * GraphQL access for agents (decision 13). Agents pick only the fields they
 * need, which keeps responses (and tokens) small. Mutations are writes and are
 * refused unless BIGBUCK_MCP_ALLOW_WRITES=true, like the REST write tools.
 */

/** True when the document contains a mutation operation. */
export function isMutation(document: string): boolean {
  return isGraphqlMutation(document)
}

export async function callGraphql(
  cfg: ApiConfig,
  document: string,
  variables: Record<string, unknown> = {},
): Promise<{ status: number; body: unknown }> {
  if (isMutation(document) && !cfg.allowWrites) {
    throw new Error('Mutations are disabled. Set BIGBUCK_MCP_ALLOW_WRITES=true to allow GraphQL writes.')
  }
  const res = await fetch(`${cfg.baseUrl}/graphql`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-Request-Id': `mcp-${randomUUID()}`,
      ...authHeaders(cfg),
    },
    body: JSON.stringify({ query: document, variables }),
  })
  const text = await res.text()
  let body: unknown = text
  try {
    body = text ? JSON.parse(text) : null
  } catch {
    body = text
  }
  return { status: res.status, body }
}

export { CURATED_TOOLS } from './curated.js'
