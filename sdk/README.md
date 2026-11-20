# `@bigbuck/sdk`

Thin TypeScript client for the Big Buck `/v1` REST API. Built for **company setup**, **recruiter ops**, and scripts. The Remix app keeps its own fetch helpers; MCP talks HTTP directly — this package is the typed channel the CLI uses.

## Install

```bash
cd sdk
pnpm install
pnpm run generate   # refreshes generated/operations.json from openapi/openapi.yaml
pnpm test
pnpm run build
```

## Usage

```ts
import { BigBuckClient } from '@bigbuck/sdk'

const client = BigBuckClient.fromEnv()
// or: new BigBuckClient({ baseUrl, token })

await client.listPeople()
await client.createConfigPlan([{ kind: 'PipelineTemplate', key: 'eng', spec: { name: 'Eng' } }])
await client.createImport({ csv: '...', dryRun: true })

// Any OpenAPI operationId (same catalog MCP generates tools from):
await client.invoke('listDncCompanies')
await client.invoke('createDncCompany', {
  body: { dnc_company: { domain: 'blocked.test', reason: 'partner' } },
})

// GraphQL (same curated tools as MCP, or any document):
await client.curatedGraphql('gql_whoami')
await client.curatedGraphql('gql_person', { id: personId })
await client.graphql('query { viewer { roleKey } }')
```

Env: `BIGBUCK_API_URL`, `BIGBUCK_TOKEN`, optional `BIGBUCK_ACT_AS_AGENT`.

Calls send `Authorization: Bearer` and `X-Bigbuck-Surface: cli`; writes add `Idempotency-Key`. Errors throw `BigBuckApiError` with problem+json fields.

## Surface

| Area | Methods |
|---|---|
| OpenAPI catalog | `listOperations`, `invoke(operationId, args)` |
| GraphQL | `graphql`, `curatedGraphql`, `listCuratedGraphqlTools` |
| People / jobs / applications | list, get, create; move / reject |
| Projects (pools) | list, create, members, add, convert |
| Sequences | list, create, enroll, stop |
| Config | listPlans, createPlan, applyPlan |
| Import | list, get, create (CSV people) |
| Agents | list, create, credential, pause, resume, revoke |

`generated/operations.json` is produced from [`../openapi/openapi.yaml`](../openapi/openapi.yaml) — the same contract as MCP. See `@bigbuck/cli` for the command-line wrapper.
