import { BigBuckClient } from '@bigbuck/sdk'

import { flagString, type ParsedArgs } from './args.js'

export function clientFromArgs(parsed: ParsedArgs, tokenProvider?: () => Promise<string>): BigBuckClient {
  const token = flagString(parsed.flags, 'token') ?? process.env.BIGBUCK_TOKEN
  const org =
    flagString(parsed.flags, 'org', 'organization-id') ??
    process.env.BIGBUCK_ORG_ID ??
    process.env.X_ORGANIZATION_ID
  if (!token && !tokenProvider && !org) {
    throw new Error('Run bigbuck auth login, or explicitly supply a compatibility token with BIGBUCK_TOKEN')
  }
  return new BigBuckClient({
    demoGeneration: process.env.BIGBUCK_DEMO_GENERATION ? Number(process.env.BIGBUCK_DEMO_GENERATION) : undefined,
    baseUrl:
      flagString(parsed.flags, 'api-url') ??
      process.env.BIGBUCK_API_URL ??
      process.env.RAILS_API_URL ??
      'http://127.0.0.1:3000',
    token,
    tokenProvider,
    organizationId: org,
    actorId:
      flagString(parsed.flags, 'actor', 'actor-id') ??
      process.env.BIGBUCK_ACTOR_ID ??
      process.env.X_ACTOR_ID,
    actAsAgentId: flagString(parsed.flags, 'as-agent') ?? process.env.BIGBUCK_ACT_AS_AGENT,
    actorType: 'cli',
  })
}
