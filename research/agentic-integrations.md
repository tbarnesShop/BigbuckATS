# 05 — Agentic Integrations

## Goal

Define how AI agents should interact with Big Buck without compromising security, auditability, or human control.

## Core principle

Agents should not get raw database access. They should get **narrow tools** with explicit permission boundaries.

## Recommended integration model

### 1) MCP server for tool access
Expose a Model Context Protocol server that offers safe, named tools such as:

- `listJobs`
- `getJob`
- `searchCandidates`
- `getCandidate`
- `listApplications`
- `scoreResume`
- `summarizeCandidate`
- `draftOutreach`
- `generateInterviewQuestions`
- `createNoteDraft`
- `createCandidateDraft`
- `suggestNextStage`

### 2) Event-driven backend
Emit domain events for important changes:

- candidate created
- application created
- stage changed
- resume parsed
- score generated
- outreach drafted
- interview scheduled

These events can drive notifications, automations, and agent follow-up tasks.

### 3) The user's permissions, no more
Decided 2026-10-24: an agent acts for a user and may do exactly what that user may do, within the scopes its credential was granted. There is no separate list of actions reserved for humans. Organizations decide how far agents go by the scopes they grant (an agent given only `applications:write` cannot reject or send), and every agent action is recorded with `actor_type = agent` and the delegating user, so it can be reviewed and undone like any other change.

## Agent capabilities that are worth building

### Low-risk, high-value
- resume parsing
- job description summarization
- candidate summarization
- match explanation generation
- interview question suggestions
- note summarization
- duplicate detection

### Medium-risk
- outreach drafting
- pipeline triage suggestions
- shortlist suggestions
- application form autofill suggestions

### High-risk
- automatic stage movement
- automatic rejection
- automatic candidate ranking without explanation
- sending external messages

## Guardrails

### Every tool must have
- scoped permissions
- audit logs
- idempotency where relevant
- input validation
- output truncation or redaction rules for PII

### Every AI result must have
- source data reference
- confidence or rationale
- versioning of model/prompt where practical

## Why this matters

Recruiting data is sensitive. Agent features become dangerous quickly if they are built as opaque automation. Big Buck needs to make AI useful without making it invisible.

## Integration surface beyond MCP

### Webhooks
Good for external automation and SaaS integration.

### Internal job queue
Good for background enrichment and asynchronous agent tasks.

### CLI assisted flows
Good for local admin operations and power users.

## Reference point from the research

The `agentic-recruitment-protocol` repo surfaced in discovery, which is useful as a signal that the ecosystem is moving toward agent-aware recruiting workflows. Big Buck should be compatible with that direction without copying an immature protocol shape blindly.

## Decision

Use MCP for agent tooling, use events for workflow automation, and give agents the permissions of the user they act for, narrowed by scopes.

## Build plan

1. define a small, stable tool catalog
2. implement read-only tools first
3. add write tools, each needing the same permission as the matching API call
5. attach audit logs and permission scopes to every tool call
