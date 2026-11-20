# 06 — API Strategy

> **Updated 2026-10-24.** The REST-first decision stands. This revision adds the contract the competitor review called non-negotiable ([`competitor-api-deep-dive.md`](./competitor-api-deep-dive.md) §4): conventions, a versioning policy, workflow commands, incremental sync, and the event and webhook contract. The resource map now covers the unified ATS + talent CRM model and configuration as code.
>
> Further update the same day: per-job pipeline edits ([`job-pipelines.md`](./job-pipelines.md)) and company-defined dimensions ([`org-structure.md`](./org-structure.md)) add job pipeline commands, dimension endpoints and two job events.
>
> It also settles an inconsistency: earlier docs described a stage move as `PATCH /applications/:id/stage` here and `POST /applications/:id/move-stage` in an earlier architecture doc. Both are replaced by `POST /applications/{id}/transitions` (see [Commands](#commands-not-patches)).

## Question

For Big Buck, is GraphQL better than REST for API calls?

## Short answer

**No, not as the primary API.**

Use **REST as the default public and internal application API**. Add GraphQL later only if a specific front-end area truly needs it.

## Why REST is the right default

### 1) ATS is command-heavy
ATS software is mostly about explicit actions:

- create job
- add candidate
- attach resume
- move stage
- add note
- schedule interview
- approve outreach

REST maps naturally to these resource and action endpoints.

### 2) CLI and agent tooling prefer explicit endpoints
A CLI and MCP tools are easier to implement when the server exposes stable, predictable endpoints with clear verbs and payloads.

### 3) File upload and webhook flows are simpler
ATS systems deal with:

- resume uploads
- attachments
- document downloads
- webhook callbacks
- integration tokens

These are easier to reason about with REST.

### 4) Caching and observability are simpler
REST is easier to cache, log, debug, and rate limit in standard infrastructure.

### 5) Security is easier to keep understandable
REST makes permission checks explicit at the endpoint level. That is valuable when candidate data and hiring actions are sensitive.

## Where GraphQL helps

GraphQL is useful when:

- a page needs many related entities in one view
- the UI has a lot of nested relationships
- you want to minimize round trips for a very rich screen

Examples:
- recruiter dashboard
- candidate detail page
- complex job analytics view

## Why GraphQL should not be the starting point

### 1) More authorization complexity
Field-level permissions are harder to get right.

### 2) More operational complexity
Query cost, N+1 behavior, caching strategy, and rate limiting all require extra work.

### 3) More schema design overhead
You have to design a stable graph before you know which screens need it.

### 4) Worse fit for command-style workflows
Creating records and moving workflow states is more naturally expressed as REST endpoints or explicit actions.

## Recommended API shape

### Public application API
- REST JSON
- explicit resources
- stable versioning
- idempotent writes where possible
- consistent error format

### Internal service boundaries
- same domain services behind the API
- no duplicated logic in CLI or agent layers
- the web app uses only public endpoints, so the API can never lag the product

### Optional future GraphQL
- only if the UI proves a real need
- ideally as a read model or BFF layer, not the only API
- the likely first use is the person profile page (person, applications, project memberships, sequence status and timeline in one round trip)

## Conventions

One OpenAPI 3.1 document is the source of truth. It generates the reference docs, the TypeScript SDK the CLI uses, the MCP tool definitions and the contract tests.

| Concern | Rule |
|---|---|
| Base URL | `https://api.<domain>/v1/`. Paths are plural, kebab-case nouns; JSON fields are `snake_case`. |
| Tenancy | The organization comes from the credential. A user who belongs to several organizations picks one with the `Bigbuck-Organization` header. Paths never carry an org id. |
| Auth | OAuth 2.0 authorization code with PKCE for apps; device flow for `bigbuck login`; client credentials for server integrations; scoped API keys (`bb_live_…`, `bb_test_…`) for scripts. Refresh-token rotation keeps the previous token valid for 60 seconds, so parallel workers do not race each other (a Lever pain point). |
| Scopes | Mirror [`permissions.md`](./permissions.md): `people:read`, `applications:write`, `applications:transition`, `offers:read`, `config:apply`, and so on. Default deny. |
| Versioning | Dated `Bigbuck-Version: 2026-10-01` header, pinned per credential at creation. See [Versioning policy](#versioning-policy). |
| IDs | UUIDv7 strings. |
| Pagination | Cursor based: `limit` (max 200), response `next_cursor` and `has_more`. Filters stay attached to the cursor, so page 5 is filtered like page 1. `include_total=true` returns a total count. A `4xx` is never a silent end of data. |
| Incremental sync | Every list endpoint accepts `sync_token` and returns a new one, for credentials with an org-wide read scope on that resource. See [Incremental sync](#incremental-sync). |
| Validation | Request bodies are validated against the contract exactly as sent: no type coercion, so `"30"` is not accepted where a number is expected. Query strings and path parameters are coerced to their declared types. |
| Filtering | `filter[status]=open&filter[updated_at][gte]=2026-10-01T00:00:00Z`; dimensions by key, optionally with descendants: `filter[dimensions.department]=engineering&filter[dimensions.department][descendants]=true`. Anything richer goes to `POST /search`. |
| Expansion | `expand[]=person&expand[]=current_stage`, maximum depth 2, checked against the caller's scopes. |
| Concurrency | Every mutable resource returns an `ETag` (its `version`). `PATCH` and commands accept `If-Match`; a stale version returns `412`. |
| Idempotency | Every `POST` accepts `Idempotency-Key`. The first response is stored for 24 hours and replayed; the same key with a different body returns `409`. |
| Errors | RFC 9457 `application/problem+json` with `type`, `title`, `status`, `detail`, plus a stable `code`, the offending `param` and the `request_id`. |
| Rate limits | Token bucket per credential, reported in `RateLimit-Policy` and `RateLimit` headers, `429` with `Retry-After`. Starting targets: 50 requests/second sustained, 100 burst. The public apply endpoint is limited per posting and per IP, never by a low global cap (Lever caps application creation at 2/second). |
| Bulk | `POST /batch` runs up to 100 operations; large loads use import jobs. |
| Test mode | `bb_test_` credentials hit a sandbox organization with the same API, seeded with fake data. |

## Versioning policy

Greenhouse retired Harvest v1/v2 on Aug 31, 2026 and changed the credential model at the same time, forcing every integrator to rebuild at once. Big Buck commits to the opposite in writing:

- **Additive changes ship without a new version:** new endpoints, new optional request fields, new response fields, new event types and new enum values in fields documented as open.
- **Breaking changes ship under a new dated version:** removing or renaming a field, changing a type, tightening validation or changing default behavior.
- **Old versions stay supported for at least 18 months** after their successor ships. Responses on a deprecated version carry `Deprecation` and `Sunset` headers, and the dashboard lists which credentials still use it.
- **Credentials never change with a version.** A key that works on one version works on all supported versions.
- **Upgrades are per credential and reversible** for 72 hours, and can be tried in test mode first.
- **Webhooks are versioned with their endpoint:** each webhook endpoint is pinned to a version, so payload shapes never change underneath a consumer.

## Commands, not patches

`PATCH` edits plain fields (a job title, a person's headline). Anything with workflow meaning is a command endpoint. Commands check permissions and guards, write the state change, history, audit and outbox event in one transaction, and return the updated resource. This follows [`workflow.md`](./workflow.md) and Greenhouse's v3 decision to pull rejection out of application edits.

| Command | Endpoint | Notes |
|---|---|---|
| Move stage | `POST /applications/{id}/transitions` | Body: `to_stage_key` or `to_stage_id`, `reason`. Checks exit and entry guards. |
| Reject | `POST /applications/{id}/reject` | Body: `reason_key`, `note`, `notify_candidate`, `send_at`. Keeps the current stage for funnel reporting. |
| Unreject | `POST /applications/{id}/unreject` | Returns to the stage it was rejected at. |
| Withdraw | `POST /applications/{id}/withdraw` | Body: `reason_key`. |
| Hire | `POST /applications/{id}/hire` | Requires an accepted offer unless policy says otherwise. |
| Edit one job's pipeline | `POST /jobs/{id}/pipeline/overrides` | Body: an ordered list of edits (add or remove a stage or interview, rename, reorder). `If-Match` on the pipeline version. See [`job-pipelines.md`](./job-pipelines.md). |
| Revert a job edit | `DELETE /jobs/{id}/pipeline/overrides/{override_id}` | That part of the job goes back to following the template. |
| Resolve a template conflict | `POST /jobs/{id}/pipeline/rebase` | Drop or retarget the edits that no longer fit. |
| Switch a job's template | `POST /jobs/{id}/pipeline/change-template` | Body: `template_key`, stage-key map for open applications. |
| Merge people | `POST /people/{id}/merge` | Body: `merge_person_ids`. The target id survives; merged ids redirect. |
| Move a pool member | `POST /project-members/{id}/transitions` | Same body as applications. |
| Convert a pool member | `POST /project-members/{id}/convert` | Creates an application on the project's job, or on `job_id` if given. |
| Enroll in a sequence | `POST /sequences/{id}/enrollments` | Body: `person_id`, `sender_user_id`, `mailbox_connection_id` (the sender's own Gmail, or a shared mailbox they may send as). Refused for `do_not_contact`, missing consent, or a mailbox that is not active. |
| Stop a sequence | `POST /sequence-enrollments/{id}/stop` | |
| Offer workflow | `POST /offers/{id}/submit-for-approval`, `/send`, `/record-response`, `/rescind`; `POST /approvals/{id}/approve`, `/request-changes` | Full process in [`offers.md`](./offers.md) |
| Publish a posting | `POST /postings/{id}/publish`, `/close` | |

Example:

```http
POST /v1/applications/0192f1a4-7c1e-7b3a-9d2e-4f5a6b7c8d9e/transitions
Bigbuck-Version: 2026-10-01
Idempotency-Key: 5f0c2e7a-1d4b-4c8e-9a3f-2b6d8e1f4a7c
If-Match: "14"
Content-Type: application/json

{ "to_stage_key": "onsite", "reason": "Strong recruiter screen" }
```

A guard failure:

```http
HTTP/1.1 422 Unprocessable Content
Content-Type: application/problem+json

{
  "type": "https://docs.<domain>/errors/transition-guard-failed",
  "title": "Transition guard failed",
  "status": 422,
  "code": "transition_guard_failed",
  "detail": "Leaving 'recruiter-screen' requires a submitted scorecard for the 'recruiter-screen' interview.",
  "param": "to_stage_key",
  "unmet": [{ "type": "scorecard_submitted", "interview_key": "recruiter-screen" }],
  "request_id": "req_7Hc2kQ"
}
```

## Resource map

Replaces the earlier list. Org-prefixed paths (`/orgs/:orgId/jobs`) are gone; the credential selects the organization.

**Identity and organization**
- `GET /me` (the caller's organization, actor, role and effective permissions), `GET /organizations/current`
- `GET|POST /api-credentials`, `POST /api-credentials/{id}/revoke`. Scopes grant permissions; a personal credential never exceeds its user's role. The token is returned once, at creation
- `GET|POST /users`, `GET|POST /roles`, `GET /permissions`
- `GET|POST /hiring-teams`
- `GET /dimensions`, `GET /dimensions/{key}?include=values`, `POST /dimensions/{key}/values`, `PATCH /dimensions/{key}/values/{value_key}`, `POST /dimensions/{key}/values/{value_key}/archive` (replaces `/departments` and `/locations`; see [`org-structure.md`](./org-structure.md))
- `GET /variables`

**People and companies**
- `GET|POST /people`, `GET|PATCH /people/{id}`, `POST /people/{id}/merge`. `POST /people` answers `201` when it creates and `200` when an exact email match attaches, with `Bigbuck-Outcome: created | matched`. A merged id answers `308` with `Location` set to the survivor. Merge suggestions: `GET /merge-suggestions`, `POST /merge-suggestions/{id}/dismiss`
- `GET|POST /people/{id}/contact-points`, `DELETE /contact-points/{id}`
- `GET|POST /people/{id}/consents`
- `GET /people/{id}/timeline`
- `POST /people/{id}/export`, `POST /people/{id}/erase` (data subject requests)
- `GET|POST /companies`, `GET|PATCH /companies/{id}`

**Hiring**
- `GET|POST /requisitions`, `GET|PATCH /requisitions/{id}`, plus approval commands
- `GET|POST /jobs`, `GET|PATCH /jobs/{id}`. Requisitions, jobs and postings carry a `dimensions` object keyed by dimension key, e.g. `{ "department": "platform", "level": "ic6" }`. Creating a job without `pipeline_template` picks the default template from its dimensions.
- `GET /jobs/{id}/pipeline` (resolved stages and interviews, each with `origin`), `GET /jobs/{id}/pipeline/overrides`, `GET /jobs/{id}/pipeline/versions`, plus the job pipeline commands above
- `GET|POST /postings`, `POST /postings/{id}/publish`, `POST /postings/{id}/close`
- `GET|POST /applications`, `GET|PATCH /applications/{id}`, plus the commands above. `POST /applications` accepts an inline `person`; an exact email match attaches to the existing person without overwriting it, and phone or name matches create merge suggestions ([`data-model.md`](./data-model.md#contact-point)).
- `GET /applications/{id}/transitions` (history)
- `GET|POST /applications/{id}/notes`
- `GET|POST /interviews`, `POST /interviews/{id}/reschedule`, `POST /interviews/{id}/cancel`, `POST /interviews/{id}/scorecards`. Interviews are created automatically when an application enters a stage that defines them; `POST /interviews` adds an extra one.
- `POST /applications/{id}/offers`, `GET|PATCH /offers/{id}`, `GET /offers/{id}/versions`, `POST /offers/{id}/documents`, `POST /offers/{id}/approval-preview`, plus offer commands ([`offers.md`](./offers.md#api))
- `GET /applications/{id}/hire-packet`

**Scheduling** ([`scheduling.md`](./scheduling.md#api))
- `POST /applications/{id}/scheduling/suggestions` (dry run), `POST /applications/{id}/scheduling/bookings`
- `POST /applications/{id}/scheduling-links`, `POST /applications/{id}/availability-requests`
- `GET|PATCH /users/{id}/interviewer-profile`, `GET|POST /interviewer-pools`, `GET|POST /calendar-connections`

**Communications** ([`candidate-communications.md`](./candidate-communications.md#api))
- `GET|POST /message-templates`, `POST /message-templates/{key}/preview`, `POST /message-templates/resolve` (dry run)
- `GET /scheduled-messages`, `POST /scheduled-messages/{id}/cancel`

**Setup** ([`owner-setup.md`](./owner-setup.md#api))
- `GET /setup`, `PUT /setup/steps/{step}` (with `dry_run`), `POST /setup/complete`, `GET /setup/checklist`

**Compliance** ([`consent-and-compliance.md`](./consent-and-compliance.md#api))
- `GET /people/{id}/compliance` (which policies apply, and why), `POST /people/{id}/consents/{purpose}/withdraw`
- `GET /compliance/policies`, `GET /notices/{key}/versions`, `GET /compliance/retention-preview`
- `GET|POST /data-requests`, `POST /data-requests/{id}/complete`

**Talent CRM**
- `GET|POST /projects`, `GET|PATCH /projects/{id}`
- `GET|POST /projects/{id}/members`, plus member commands
- `GET|POST /sequences`, `GET|POST /sequences/{id}/enrollments`, `POST /sequence-enrollments/{id}/stop`
- `GET /communications`, `POST /communications` (send from a template or log a call or message; `send_at` schedules it)
- `GET|POST /mailbox-connections`

**Documents and search**
- `POST /documents` returns a signed upload URL; `GET /documents/{id}/download` returns a short-lived signed download URL
- `POST /search` with `query`, `filters`, `facets` and `object_types`

**Configuration** (see [`recruiting-as-code.md`](./recruiting-as-code.md))
- `GET /pipelines?scope=template`, `GET /pipelines/{id}/versions`, `GET /pipelines/{id}/jobs` (jobs built from a template, with link mode and review status)
- `GET /scorecard-templates`, `GET /custom-fields`, `GET /rejection-reasons`
- `GET /config/export` — the current configuration as a manifest, with its revision (built in M3, as are the plan, apply, revision, rollback and `GET /config/diff` endpoints below; break glass comes with repository lock in M8)
- `POST /config/plans` — diff a submitted configuration against the head revision
- `POST /config/applies` — apply a plan
- `GET /config/revisions`, `GET /config/revisions/{number}`
- `POST /config/rollbacks` — apply an earlier revision's manifest as a new revision
- `POST /config/break-glass`, `POST /config/break-glass/{id}/close`, `GET /config/break-glass` — time-limited emergency override of repository lock

**Events, webhooks, integrations, imports**
- `GET /events` (30-day replayable feed), `GET /events/{id}`
- `GET|POST /webhook-endpoints`, `POST /webhook-endpoints/{id}/test`, `GET /webhook-endpoints/{id}/deliveries`, `POST /webhook-deliveries/{id}/retry`
- `GET|POST /integrations`
- `GET|POST /imports`, `GET /imports/{id}` (see [`migration-sync-engine.md`](./migration-sync-engine.md))
- `GET /audit-events`

**Public, unauthenticated**
- `GET /public/organizations/{slug}/postings`, `GET /public/postings/{id}`
- `POST /public/postings/{id}/applications` — the apply endpoint, with bot protection, per-posting and per-IP limits, resume upload, the notices and consents the company's policies require, and EEO collection through its own path

Built in M2b (under `/v1/public`) except the bot challenge and limits, which are **not yet implemented** (#60 item 2); notices, consents and EEO arrived with compliance (M7):
- **Bot challenge (planned).** A reCAPTCHA Enterprise token in the `Bigbuck-Challenge` header, checked for the `apply` action and a minimum score. If Google cannot be reached, the endpoint answers `503` rather than letting the application through. Production refuses to start without it.
- **Limits (planned).** Shared across API instances in MySQL or Solid Cache: 5 applications per address and posting per 10 minutes, 50 per address per hour, 600 per posting per minute. Bucket keys are HMACs, so no IP address is stored. Limits are counted before the challenge, so a flood of bad tokens never reaches the paid challenge service. A refusal is `429` with `Retry-After`.
- **One answer for everyone.** Every accepted application gets the same `202` receipt, whether the applicant is new, matched an ordinary existing person, collided with someone hidden (kept apart as a held duplicate), or already has an open application for the job. An unknown or closed posting is `404`.
- **Resume upload.** A declared resume returns a 15-minute upload URL into the quarantine bucket; the file is scanned before anyone can open it.
- `GET /public/scheduling/{token}`, `POST /public/scheduling/{token}/book`, `POST /public/availability/{token}`
- `GET /public/offers/{token}`, `POST /public/offers/{token}/accept`, `POST /public/offers/{token}/decline`
- `GET /public/consent/{token}`, `POST /public/consent/{token}` (give or withdraw consent), `POST /public/data-requests`

**AI helpers (draft only)**
- `POST /ai/resume-parses`, `POST /ai/person-summaries`, `POST /ai/outreach-drafts`
- results are stored as drafts with model, prompt version and input references; nothing is sent or moved without a human command ([`agentic-integrations.md`](./agentic-integrations.md))

## Incremental sync

Every list endpoint accepts `sync_token`:

1. First call without a token: the API returns every matching record, paged, and a `next_sync_token` on the last page.
2. Later calls pass that token and receive only records created, updated or deleted since. Deleted records come back as `{ "id": "…", "deleted": true }`.
3. Goal: a token never skips a change, even when a slow transaction commits after a fast one. Today `SyncFeed` pages on an opaque `updated_at + id` token (`app/services/sync_feed.rb`), which does not yet hold the watermark back for in-flight transactions (#60 item 7).
4. Tokens are valid for 30 days. An expired token returns `410 Gone` with `code: sync_token_expired`, and the client starts a full sync. It never returns an empty page that looks like "no changes".
5. **Unscoped readers only in v1.** A record can enter or leave a scoped credential's view without the record changing (a job is retagged, a scope is edited), so incremental sync cannot be exact for scoped credentials. A scoped credential that sends `sync_token` gets `403` with `code: sync_requires_unscoped_read`; it uses `GET /events` and periodic full reads instead.

## Events and webhooks

Every committed change produces exactly one event in the outbox. Webhooks, the `GET /events` feed, the person timeline, search updates and automations all read the same stream.

### Envelope

```json
{
  "id": "0192f1b0-3a2c-7e4d-8b1a-6c9d0e2f3a4b",
  "type": "application.stage_changed",
  "api_version": "2026-10-01",
  "organization_id": "0192f1a4-0000-7000-8000-00000000a001",
  "occurred_at": "2026-10-24T15:04:05Z",
  "actor": { "type": "user", "id": "0192f1a4-0000-7000-8000-00000000b001", "source_surface": "web" },
  "subject": { "type": "application", "id": "0192f1a4-7c1e-7b3a-9d2e-4f5a6b7c8d9e", "version": 15 },
  "data": { "from_stage_key": "recruiter-screen", "to_stage_key": "onsite", "reason": "Strong recruiter screen" },
  "previous": { "current_stage_key": "recruiter-screen" },
  "request_id": "req_7Hc2kQ"
}
```

### Catalog (v1)

| Object | Events |
|---|---|
| `person` | `created`, `updated`, `merged`, `erased`, `consent_changed` |
| `setup` | `step_completed`, `completed`, `checklist_item_completed` |
| `notice` | `shown` |
| `compliance` | `action_blocked` |
| `retention` | `extension_requested`, `applied` |
| `data_request` | `created`, `completed` |
| `company` | `created`, `updated` |
| `requisition` | `created`, `status_changed` |
| `job` | `created`, `updated`, `status_changed`, `pipeline_changed`, `pipeline_needs_review` |
| `dimension` | `value_created`, `value_updated`, `value_archived` |
| `posting` | `published`, `closed` |
| `application` | `created`, `stage_changed`, `rejected`, `unrejected`, `withdrawn`, `hired` (moves caused by pipeline changes are `stage_changed` with `reason` `pipeline_edit` or `pipeline_upgrade`) |
| `interview` | `scheduled`, `rescheduled`, `cancelled`, `completed`, `interviewer_declined`, `interviewer_replaced`, `needs_attention` |
| `scheduling_link` | `sent` |
| `availability` | `submitted` |
| `scorecard` | `submitted` |
| `offer` | `created`, `version_created`, `submitted`, `approval_step_completed`, `changes_requested`, `approved`, `sent`, `viewed`, `accepted`, `declined`, `expired`, `rescinded` |
| `communication` | `sent`, `delivered`, `bounced`, `replied` |
| `scheduled_message` | `cancelled` |
| `project_member` | `added`, `stage_changed`, `converted`, `removed` |
| `sequence_enrollment` | `started`, `step_sent`, `replied`, `stopped` |
| `document` | `uploaded`, `parsed` |
| `config` | `applied`, `rolled_back`, `break_glass_opened`, `break_glass_closed`, `break_glass_reconciled` |
| `webhook_endpoint` | `failing`, `recovered` |
| `ping` | sent by `POST /webhook-endpoints/{id}/test` |

EEO data never appears in events. Endpoints can be set to **thin payloads**, which omit `data` and `previous` so the consumer fetches the record with its own scopes.

### Delivery guarantees

- **At least once.** Consumers dedupe on `id`.
- **Unordered** (decided 2026-10-24). Retries make delivery order unreliable, so none is promised. Every event carries `subject.version`; consumers keep the highest version they have seen and fetch the record when they need the current state. Big Buck's own consumers (timeline, search) process events in order internally.
- **Signed in a header**, not the body (a Lever complaint): `Bigbuck-Signature: t=1792854245,v1=<hex HMAC-SHA256 of "t.body">`. The SDK helper rejects timestamps older than 5 minutes. Two secrets can be active during rotation.
- **Retries** with exponential backoff and jitter for 72 hours.
- **Never disabled silently.** After 24 hours of failures the endpoint is marked `failing`, admins are emailed and a `webhook_endpoint.failing` event is emitted. Delivery keeps retrying until the 72-hour window ends; after that, events stay available from `GET /events` for 30 days, and `POST /webhook-deliveries/{id}/retry` replays any delivery.
- **Inspectable.** Every attempt is stored with status code, latency and a truncated response snippet. Request bodies are not stored; replays rebuild them from the event.

## MCP server and CLI

- The CLI ([`cli-strategy.md`](./cli-strategy.md)) uses the generated TypeScript SDK; it has no private endpoints.
- The MCP server's tools are generated from the same OpenAPI operations and carry the same scopes. Write tools are opt-in per agent and default to drafts, as [`agentic-integrations.md`](./agentic-integrations.md) requires. Every agent call is recorded with `actor.type = agent` and the delegating user.

## Decision

REST with one OpenAPI document is the primary contract. Workflow changes are commands, every change is an event, every list is syncable, and versions never break integrators without 18 months' notice. GraphQL remains a possible later read layer, not the foundation.

## Build plan

1. write the OpenAPI document for people, applications (with commands), jobs, pipelines and webhooks first
2. generate the SDK, contract tests and MCP tool definitions from it in CI; fail the build on undeclared breaking changes
3. build the CLI on the SDK, then the config plan/apply endpoints
4. add the talent CRM resources (projects, sequences, communications) in phase 2
5. revisit GraphQL only after the UI proves a real aggregation problem
