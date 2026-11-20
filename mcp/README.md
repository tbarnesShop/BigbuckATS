# Big Buck MCP

MCP server for Big Buck. Tools are generated from [`../openapi/openapi.yaml`](../openapi/openapi.yaml) and proxy to the same `/v1` REST API as the Remix app, SDK, and CLI (`bigbuck api <operationId>` uses the same `operationId` set). Curated GraphQL tools are shared with `@bigbuck/sdk` / `bigbuck gql`.

## Setup

```bash
cd mcp
pnpm install
pnpm run generate   # writes generated/tools.json + TOOLS.md
pnpm test
```

## Run

```bash
export BIGBUCK_API_URL=http://127.0.0.1:3000
export BIGBUCK_TOKEN=bb_live_…              # agent token: POST /v1/agents/{id}/credentials
export BIGBUCK_MCP_ALLOW_WRITES=false        # default: reads only
pnpm exec tsx src/server.ts
# or: pnpm run generate && pnpm run build && pnpm start
```

Write tools (POST/PATCH/DELETE) refuse unless `BIGBUCK_MCP_ALLOW_WRITES=true`. Every call sends `Authorization: Bearer` and `X-Bigbuck-Surface: mcp`. The agent acts with its scopes ∩ its owner's role; audit records the agent and the owner it acted for.

## Cursor / Claude Desktop

```json
{
  "mcpServers": {
    "bigbuck": {
      "command": "pnpm",
      "args": ["--dir", "/absolute/path/to/BigbuckATS/mcp", "exec", "tsx", "src/server.ts"],
      "env": {
        "BIGBUCK_API_URL": "http://127.0.0.1:3000",
        "BIGBUCK_TOKEN": "bb_live_…",
        "BIGBUCK_MCP_ALLOW_WRITES": "false"
      }
    }
  }
}
```

## GraphQL tools

Besides one tool per REST operation, the server exposes GraphQL for agents, so they fetch only
the fields they need:

| Tool | Does |
|---|---|
| `gql_whoami` | Who the agent is, who it acts for, effective permissions |
| `gql_job_pipeline` | A job's stages and applications in one call |
| `gql_person` | A person with applications and custom field values |
| `gql_custom_field_definitions` | Field definitions for person, job or application |
| `gql_move_application_stage` | Move an application (pass `expectedVersion`) — write |
| `gql_reject_application` | Reject an application — write |
| `gql_set_custom_field_value` | Set or clear a typed custom field value — write |
| `graphql_query` | Any document against `schema.graphql`; mutations need writes enabled |

Mutations return `userErrors` (`stale_version`, `invalid_transition`, `invalid_value`, …) for the
agent to act on. CI validates the curated documents against `schema.graphql`.

## Design

- One OpenAPI contract → MCP tool names are `operationId`s
- Organization and identity come from the agent token, never a tool argument
- Idempotency keys auto-minted on writes
- See `generated/TOOLS.md` after `pnpm run generate`
