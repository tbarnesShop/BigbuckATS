# Reference, reality, and what comes next

This proof of concept is meant to be inspected. References below come from the repository's current contracts rather than a separate marketing description.

## Contract-backed references

- [REST operations and request schemas](/docs/reference/rest)
- [GraphQL schema](/docs/reference/graphql)
- [MCP tools and input schemas](/docs/reference/mcp)
- [CLI command help](/docs/reference/cli)

Runtime behavior is demonstrated by live responses. A sparse schema in the committed OpenAPI contract remains sparse in this reference; the docs do not invent missing fields.

## Implemented

Rails/MySQL domain records, tenant-scoped identity, scoped agent principals, REST, GraphQL, MCP tools (full OpenAPI catalog plus curated GraphQL), SDK/CLI operations including `bigbuck api <operationId>` for every REST operation and `bigbuck gql` for curated/ad hoc GraphQL, recruiter UI over the same API, audit/outbox behavior, versioned custom fields, recruiting workflows, and privacy mechanics exist in the codebase.

## Specific to this lab

Two shared sample organizations, scheduled resets, fixed seed personas, browser explorers, locally captured outbound effects, temporary CLI files, and the extra prohibition on destructive and identity-changing actions are demonstration behavior.

Other visitors can change the same records. Resetting a workspace invalidates its credentials. The original automated test organization is separate.

The explorers require a Node host that can start the built MCP and CLI processes and write temporary demo files and server credential files. An Edge-only deployment cannot run them. Temporary CLI directories require host cleanup. Expired credential files are removed on lookup and issuance. Multiple web hosts need shared credential storage; a managed vault, rate limits, quotas, and exhaustive abuse testing remain hardening work.

## Planned for V2

A live conversational agent will use the same MCP layer, permissions, audit attribution, and record inspection. V1 makes no paid model calls.

Production hardening, broader load/security verification, SAML/SCIM, and several partner/provider integrations are separate work. Existing adapter seams are not evidence of a completed production integration.

## Boundaries worth testing

Try an action outside a persona's role. Attempt an archive as Owner. Open a record that another visitor changed. Inspect a failure response. These are useful experiments, not interruptions to a scripted performance.

[Back to the lab →](/session)
