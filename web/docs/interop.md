# Different interfaces. Shared meaning.

Interoperability is useful when a person, relationship, or action means the same thing wherever work starts. Big Buck puts domain behavior in Rails services and uses several interfaces to reach it.

## REST and OpenAPI

REST lives under `/v1`. The committed OpenAPI document is the shared product contract: every `operationId` appears in the lab API explorer, drives the generated MCP REST catalog, and is callable from the SDK/CLI via `bigbuck api <operationId>`. Public pages, OAuth, webhooks, uploads, imports, and the ergonomic CLI commands also use REST.

[Browse the REST reference →](/docs/reference/rest)

## GraphQL

The web app and agents use `/graphql` for nested reads and command mutations. The schema is committed in the repository. Browser sessions ordinarily use registered queries; agents can use the allowed ad hoc GraphQL path with depth and complexity limits.

GraphQL mutations can return `userErrors` such as stale versions or invalid transitions. An HTTP 200 response can still contain a GraphQL error, so inspect the body too.

[Read the GraphQL schema →](/docs/reference/graphql)

## MCP is a protocol connection

The MCP server is a separate process using JSON-RPC over stdio. The lab connects with an MCP client and discovers tools through the protocol; it does not imitate a tool call by drawing a terminal transcript.

Generated REST tools (one per OpenAPI `operationId`) sit beside curated GraphQL tools such as `gql_whoami`, `gql_job_pipeline`, and `gql_person`. Write execution is explicitly enabled for the lab process; role and demo limits still apply in Rails.

[Browse the MCP reference →](/docs/reference/mcp)

## CLI and SDK

The CLI is a thin operational interface over the TypeScript SDK. Ergonomic commands cover people, jobs, applications, pools, sequences, agents, CSV imports, and configuration plans. The same OpenAPI and curated GraphQL surfaces MCP exposes are also available directly:

```sh
bigbuck api list --q dnc
bigbuck api listDncCompanies
bigbuck api createDncCompany --body '{"dnc_company":{"domain":"blocked.test","reason":"partner"}}'
bigbuck gql whoami
bigbuck gql person --id <person-id>
bigbuck gql query --query 'query { viewer { roleKey } }'
bigbuck person list
bigbuck project create --name "Future platform team"
bigbuck import csv --file sample.csv --dry-run
```

Path and query parameters are `--name=value` flags (hyphens become underscores). JSON bodies use `--body`. `bigbuck api list` shows every operationId; `bigbuck gql list` shows the curated GraphQL tools.

In the browser lab, commands execute the actual CLI with argument parsing and a temporary working directory. It is not a machine shell. The bundled `sample.csv` is available there; arbitrary filesystem access is not. Identity and public-token endpoints stay blocked in the lab, matching the API explorer.

[Try in the lab →](/session?surface=cli&step=preview)

## Configuration as code

Generate a preset, preview its plan, and apply the returned plan ID. Plans use object versions to refuse conflicting changes. Custom fields and pipeline templates have real executors; not every stored configuration kind changes runtime behavior.

```sh
bigbuck config init --preset recruiting-team --dir ./bigbuck
bigbuck config plan --dir ./bigbuck
bigbuck config apply --plan-id <returned-plan-id>
```

## Retries and stale state

Writes support idempotency where implemented. A key must represent the same intended request, not unrelated operations. Version checks serve a different purpose: they prevent overwriting a record that changed after it was read.

Webhooks are asynchronous delivery of committed events. They are not a distributed transaction across connected systems.

## Hand work between interfaces

Connect mode keeps API, MCP, CLI, and UI on the same sandbox. Compare mode intentionally uses independent copies. Switch interfaces in Connect mode to see the same person record instead of four disconnected examples.

[Try the connected story →](/session?surface=api&mode=connect&step=person)
