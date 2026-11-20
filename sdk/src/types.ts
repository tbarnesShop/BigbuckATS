export type ClientOptions = {
  demoGeneration?: number
  /** API origin without trailing slash, e.g. http://127.0.0.1:3000 */
  baseUrl?: string
  /** Bearer credential (`bb_live_…` personal/agent/integration token or a `bb_sess_…` session). */
  token?: string
  /** Resolve a current access token before each request (for OAuth renewal). */
  tokenProvider?: () => Promise<string>
  /**
   * Legacy local-dev header harness only (Rails BIGBUCK_ALLOW_HEADER_AUTH=1): sent as
   * X-Organization-Id when no token is set. With a token the organization comes from the token.
   */
  organizationId?: string
  /** Legacy harness only — X-Actor-Id */
  actorId?: string
  /** Which surface is calling, for audit (cli | api | agent | mcp). Default: cli */
  actorType?: string
  /** Act as one of your own agents (session/personal tokens only). */
  actAsAgentId?: string
  /** Optional fetch implementation */
  fetch?: typeof fetch
}

export type RequestOptions = {
  method?: string
  path: string
  query?: Record<string, string | number | boolean | undefined | null>
  body?: unknown
  idempotencyKey?: string
  /** Skip org header (health, public, org create) */
  skipOrg?: boolean
}

export type ConfigDocument = {
  kind: string
  key: string
  spec: Record<string, unknown>
}

export type ImportCreateInput = {
  csv: string
  entity?: 'people'
  dryRun?: boolean
  sourceSystem?: string
  fieldMapping?: Record<string, string>
}
