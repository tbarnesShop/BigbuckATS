# A recruiting system you can take apart

Big Buck is a working experiment in what an ATS and talent CRM can become when people, programs, and agents use the same underlying system.

There is no sales funnel here. Pick a perspective, try something, and inspect what happened.

## Four ways in

**UI** is the recruiting application. **MCP** exposes discoverable tools. **API** gives you editable HTTP requests. **CLI** puts recruiting operations in a terminal.

They share one domain and one OpenAPI contract. Every `/v1` `operationId` is available as an MCP REST tool, through the SDK/`bigbuck api <operationId>` path, and in the lab API explorer. The same curated GraphQL tools MCP exposes (`gql_whoami`, `gql_person`, …) are available as `bigbuck gql …`, with ad hoc documents via `bigbuck gql query`. The UI covers the same recruiter-facing workflows over that API (plus registered GraphQL for nested pages).

## Choose a route

- **Explore:** follow a suggested story, then wander.
- **Compare:** do the same CRM task through four interfaces, each with its own sample workspace.
- **Connect:** pass one record between interfaces. All steps use the CLI sandbox, including its UI view.

[Try in the lab →](/session?surface=api&mode=explore&operation=listPeople)

## Choose a perspective

Personas are actual seeded organization members. Their role and team scope apply to your requests. Some actions will be refused. Those refusals tell you where the system draws a boundary.

MCP uses a distinct agent owned by your selected persona. Its permissions are bounded by that person's role and the agent's scopes. No language model is involved in V1.

## Shared, temporary, real

The two workspaces (the recruiting UI, and one shared by MCP, API and CLI) are copies of one canonical dataset in one MySQL database. They are shared with other visitors and reset on a schedule; the banner counts down to the next reset. Changes in the ordinary API sandbox do not alter the UI sandbox or automated test fixtures.

A reset invalidates old credentials. If another visitor changes a record, re-read it before retrying. Delete, archive, erasure, and identity changes are blocked in every shared workspace, even for Owner. Outbound effects are captured locally.

## Follow the evidence

An execution result shows what the system actually returned. Supported records appear in the inspector and can be opened in the UI. Guided steps are suggestions, not simulated successes.

Read [Agents as principals](/docs/agents) for the identity model, or [Data model](/docs/data-model) to understand the records.
