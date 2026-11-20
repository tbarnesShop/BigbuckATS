# `@bigbuck/cli`

CLI channel for **company setup** and **recruiter ops**. Thin wrapper over [`@bigbuck/sdk`](../sdk) → `/v1`. Ergonomic commands cover day-to-day work; `bigbuck api` reaches every OpenAPI `operationId` (the same catalog MCP exposes as REST tools).

## Setup

```bash
cd ../sdk && pnpm install && pnpm run build
cd ../cli && pnpm install
pnpm test
pnpm run build
```

## Auth

Use an external OAuth/OIDC provider with a registered public native client and an
explicitly provisioned Big Buck identity. See [provider setup](../OAUTH.md).

```bash
export BIGBUCK_API_URL=https://api.bigbuck.example.com
export BIGBUCK_OAUTH_ISSUER=https://identity.example.com/
export BIGBUCK_OAUTH_CLIENT_ID=native-client-id
export BIGBUCK_OAUTH_AUDIENCE=https://api.bigbuck.example.com
export BIGBUCK_OAUTH_SCOPES='people:read jobs:read'
bigbuck auth login
bigbuck auth status
bigbuck person list
bigbuck auth logout
```

Login uses authorization code + S256 PKCE. The OS keychain stores short-lived
access and rotating refresh tokens; subsequent commands renew them automatically.
Use `BIGBUCK_OAUTH_CLIENT_SECRET` from a secret manager with a separate service
client for scheduled jobs. Service mode obtains client-credentials tokens and
needs no browser or keychain.

`--api-url` overrides the API address; `--as-agent` optionally acts as an owned
agent within both the OAuth and local permission ceilings. Use `--json` for
scripts. Explicit `--token` / `BIGBUCK_TOKEN` remain available for agent/session
credentials and an authorized compatibility migration. Personal/integration
tokens are rejected by default when the API enables OAuth.

## Company setup

```bash
pnpm exec tsx src/cli.ts config init --preset recruiting-team --dir ./bigbuck --org "$BIGBUCK_ORG_ID"
pnpm exec tsx src/cli.ts config plan --dir ./bigbuck
pnpm exec tsx src/cli.ts config apply --plan-id <plan uuid>
pnpm exec tsx src/cli.ts import csv --file people.csv --dry-run
pnpm exec tsx src/cli.ts import csv --file people.csv --source-system greenhouse_export
```

Presets: `recruiting-team`, `admins-only` (pipeline + rejection reasons as YAML).

## Recruiter ops

```bash
pnpm exec tsx src/cli.ts person list
pnpm exec tsx src/cli.ts person create --name "Ada Lovelace" --email ada@x.test
pnpm exec tsx src/cli.ts job create --title "Staff Engineer"
pnpm exec tsx src/cli.ts project create --name "Backend pool"
pnpm exec tsx src/cli.ts project add <projectId> <personId>
pnpm exec tsx src/cli.ts sequence enroll <sequenceId> <personId>
pnpm exec tsx src/cli.ts application move <id> --to onsite
pnpm exec tsx src/cli.ts application reject <id> --reason not-a-fit
pnpm exec tsx src/cli.ts agent list
```

## Full OpenAPI surface

```bash
pnpm exec tsx src/cli.ts api list --q offer
pnpm exec tsx src/cli.ts api listDncCompanies --json
pnpm exec tsx src/cli.ts api createDncCompany --body '{"dnc_company":{"domain":"blocked.test"}}'
pnpm exec tsx src/cli.ts api getPerson --id <person-uuid>
```

Path/query parameters are `--name=value` flags (hyphens map to underscores). JSON bodies use `--body`. This is the same `operationId` set documented under `/docs/reference/rest` and `/docs/reference/mcp`.

## GraphQL

Same curated tools as MCP, plus an ad hoc escape hatch:

```bash
pnpm exec tsx src/cli.ts gql list
pnpm exec tsx src/cli.ts gql whoami
pnpm exec tsx src/cli.ts gql person --id <person-uuid>
pnpm exec tsx src/cli.ts gql job-pipeline --id <job-uuid>
pnpm exec tsx src/cli.ts gql query --query 'query { viewer { roleKey permissions } }'
```

After build: `node dist/cli.js …` or link the `bigbuck` bin.
