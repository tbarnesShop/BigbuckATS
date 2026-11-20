# 30 — Build Plan: one enterprise platform for ATS and CRM (Rails, MySQL & Remix 3 vision)

What v1 contains, the order it is built in, and what has to be true before it ships. Companion documents:

| Document | Holds |
|---|---|
| [`architecture.md`](./architecture.md) | Services, the shared ATS + CRM table spine, design rules, scale targets and sizing, repository layout, provider interfaces |
| [`decisions.md`](./decisions.md) | Founding decisions, resolved questions, technical defaults awaiting sign-off |
| [`progress.md`](./progress.md) | What each milestone built, milestone by milestone |

In one line: the ATS and the talent CRM are one product on one schema, built for enterprise first, with the SMB experience coming later as a restricted preset of the same product ([`decisions.md`](./decisions.md#founding-decisions-2026-10-24)).

## Stack

The product and the milestones are stack-independent. The implementation is a Ruby on Rails API, a MySQL database and a Remix 3 frontend:

| Concern | Choice |
|---|---|
| API, workers, outbox delivery | One Rails app: API controllers, Solid Queue jobs, webhook/event delivery as jobs |
| Code organisation | Domain code namespaced under `app/` (models, services, jobs, mailers) |
| Database | ActiveRecord on MySQL (Cloud SQL for MySQL); `structure.sql` (not `schema.rb`) so MySQL-specific schema details survive dumps |
| Validation | Strong parameters + ActiveModel validations; API shapes pinned by the OpenAPI contract |
| Tests | Minitest + system tests (Capybara) for the end-to-end release gate |
| Jobs and fan-out | Solid Queue (jobs in MySQL) for internal work; Pub/Sub push for inbound Gmail sync, delivered into Rails webhook endpoints |
| Outbox | Transactional outbox table written in the same ActiveRecord transaction; Solid Queue jobs drain it to webhooks and the events API |
| Recruiter app and candidate pages (M9) | Remix 3 frontend (no React): its own component model, routes, forms and frames; Rails + MySQL own all persistence, and the frontend talks to Rails over the API only |
| CLI | Thor-based CLI (`bin/bigbuck`) and a TypeScript CLI/SDK talking to the same public API |
| API surface | One OpenAPI contract for the public/integration API, CLI and MCP tools; REST under `/v1` plus GraphQL at `/graphql` for the web app and agents, over one service layer ([`decisions.md`](./decisions.md#decided-2026-10-25), decision 13) |
| Google sign-in, Calendar, Gmail | Hand-rolled Google OAuth 2.0 authorization-code sign-in (`GoogleOauth`) and Google API clients; same verified-domain and delegation rules. OmniAuth is not used |
| GCP | Cloud Run (Rails), Cloud SQL for MySQL, Cloud Storage, Secret Manager |
| Tenant isolation | MySQL has no row-level security: every tenant table carries `organization_id`, the tenant is set per request from auth (`CurrentAttributes`), and a CI convention test checks every tenant table is `TenantScoped`, with tests proving cross-tenant invisibility. Composite `(organization_id, id)` keys stop cross-tenant links. This also keeps a future sharding story open (shard on `organization_id`) |

**If-rules (decided 2026-10-25):** conditions are a closed structured YAML rule schema — not CEL and not eval'd Ruby. One engine for guards, approvals, compliance and automations; type-checked at `validate`; operators grow only when a real policy needs them. See [If-rules](#if-rules) and [`decisions.md`](./decisions.md#decided-2026-10-25).

**MySQL (decided 2026-10-25):** enforce product guarantees with MySQL-appropriate mechanisms. Tenant key on every row and query, fail closed, composite FKs, tests each milestone. See [MySQL principles](#mysql-principles) and [`decisions.md`](./decisions.md#decided-2026-10-25).

**Remix 3 maturity, stated plainly:** Remix 3 is new (release-candidate stage in recent reports) and deliberately React-free, so no React component libraries carry over. The risk is contained by the architecture: the frontend is a stateless API client, so swapping the UI runtime later does not touch the backend, the schema, or the API contract.

## If-rules

Customer-authored conditions (stage guards, approval and compliance `when`, automation `where`) are **data**, evaluated by one Rails rule engine:

1. **No arbitrary code** — never `eval` Ruby or any string language.
2. **One system everywhere** — same schema for every condition site.
3. **Validate before apply** — every rule type-checks against known fields and dimension attributes at `config validate` / plan.
4. **Tiny surface** — v1 operators: `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `in`, `and`, `or`, `not`, and dimension match (value or under it). Add an operator only when a real policy needs it.
5. **Deterministic and pure** — same inputs → same yes/no; no I/O inside a rule.
6. **Readable in YAML** — recruiting ops can audit rules in a pull request.
7. **Fail closed** — missing field, wrong type, or unknown path → the condition does not match (a step `when` that fails closed skips only if the policy author used an explicit skip path; otherwise validation or evaluation refuses the unsafe case).

Canonical form (structured YAML). Dimension match stays as today’s map; comparisons use an explicit operator:

```yaml
# Policy match (unchanged shape)
when:
  job.dimensions.department: engineering
  job.dimensions.level: [ic6, ic7]

# Comparison (structured — replaces CEL strings)
when:
  op: gt
  left: offer.fields.base-salary
  right: job.dimensions.level.attributes.salary-max

# Composition
when:
  op: and
  args:
    - { op: eq, left: person.country, right: DE }
    - { op: gte, left: offer.fields.base-salary, right: 150000 }
```

The rule engine lives in the Rails domain layer and is used by config validate, plan/apply, stage moves, offer routing and compliance gates. Built in M3; consumed by M6a and M7a.

## MySQL principles

Rules:

1. **`org_id` on every tenant row** — no tenant data without the key (also the future Vitess shard key).
2. **Every query carries the tenant** — set from auth / job context (`CurrentAttributes`); CI fails tenant-table access that omits the scope.
3. **Unset tenant fails closed** — empty result or error, never unscoped reads.
4. **Composite foreign keys `(org_id, id)`** — stop cross-tenant links even when a filter is forgotten.
5. **Prove isolation every milestone** — cross-tenant invisibility tests for each new tenant table, not only M0.
6. **DB enforces structure; app enforces policy** — constraints, uniqueness, FKs in MySQL; person visibility, confidential jobs, compensation fields in application code with tests.
7. **Short transactions** — bulk work (imports, retention, re-resolution) commits in bounded chunks (≤500 rows or ≤2 seconds).
8. **Jobs may share MySQL** — Solid Queue is fine; cap worker concurrency; watch API p95 vs outbox/queue lag; keep a path to move jobs off the primary if the OLTP store saturates.
9. **Guarantees first** — keep the product promises below; implement each with MySQL-appropriate tools.

| Guarantee | MySQL approach (v1) |
|---|---|
| Tenant isolation | `org_id` + default scopes + CI lint + composite FKs + cross-tenant tests |
| Append-only evidence (consents, receipts, offer responses) | No `UPDATE`/`DELETE` for app roles; erasure goes through a privileged, tested path that only clears allowed columns |
| Erasure completeness | Inventory of person-linked tables; erasure job + verification pass that searches for residual PII; fail CI if a new FK to `people` is missing from the inventory |
| Audit / outbox / timeline retention | Time-based partitioning or equivalent table rotation aligned to retention; old audit partitions export to Cloud Storage then drop |
| Person matching | Exact email attach; MySQL full-text + prefix for suggestions; Elasticsearch later only if usage proves it necessary |
| Statement / idle limits | Session timeouts at the pool and Cloud SQL; enforce short transactions in app code |
| Search index on erasure | No index in early milestones; when added, erasure inventory must clear it |

## What v1 contains

Product scope:

| Area | In v1 |
|---|---|
| Identity | Google sign-in as the single sign-on, limited to each organization's verified Workspace domains; users invited by admins or created on first sign-in; roles, permissions, combined dimension scopes ([`permissions.md`](./permissions.md)). SAML and SCIM are v2 |
| Org structure | Company-defined dimensions with attributes and organization variables ([`org-structure.md`](./org-structure.md)) |
| ATS | Requisitions, jobs, postings, careers pages, the public apply endpoint, applications with commands, per-job pipelines from templates, interviews inside stages, scorecards ([`job-pipelines.md`](./job-pipelines.md)) |
| Talent CRM | People, contact points, companies, affiliations, projects (talent pools) with their own pipelines, sequences, communications, the person timeline, conversion from pool member to applicant ([`data-model.md`](./data-model.md#talent-crm-objects)) |
| Scheduling | Google Calendar and Meet, domain-wide delegation, the availability engine, self-scheduling, coordinator scheduling, interviewer pools ([`scheduling.md`](./scheduling.md)) |
| Offers | Offer fields and versions, approval policies, letter templates, click-to-accept, hire ([`offers.md`](./offers.md)) |
| Communications | Candidate mail sent from recruiters' own Gmail and from shared company mailboxes (such as recruiting@), with both synced so every reply lands on the person's timeline; message templates in every language, scheduled messages, reminders ([`candidate-communications.md`](./candidate-communications.md)) |
| Compliance | Company-owned policies, notices, consents, retention, data requests, legal hold, erasure that reaches every copy ([`consent-and-compliance.md`](./consent-and-compliance.md)) |
| Configuration as code | Revisions, plan and apply, rollback, the CLI, the GitHub workflow, repository lock and break glass ([`recruiting-as-code.md`](./recruiting-as-code.md)) |
| Platform | OpenAPI contract for the public/integration API, CLI, MCP tools, and the app frontend; MCP tools and SDK/CLI `invoke`/`bigbuck api` generated from that contract (ergonomic SDK methods stay hand-written); GraphQL for the web app and agents (decision 13); events API, signed webhooks, incremental sync, idempotency, rate limits ([`api-strategy.md`](./api-strategy.md)) |
| Migration | Generic CSV import and export with field mapping, dry run and provenance, behind an importer interface; no vendor-named importers in v1 ([`migration-sync-engine.md`](./migration-sync-engine.md)) |

**Not in v1:** the SMB preset and owner setup, self-serve sign-up, AI helper endpoints, an AI interviewer, fraud detection, a full candidate portal, Outlook mailboxes, Zoom, Slack, e-signature providers, job boards, LinkedIn, SMS, vendor-named importers, the EU region (v3 at the earliest). Status labels for integrations are in [`v1-scope.md`](./v1-scope.md#integrations).

## Build order

Each milestone ends with an automated test that proves it; nothing is "done" without one.

Progress is tracked in [`progress.md`](./progress.md).

| # | Milestone | Proves | Rails notes |
|---|---|---|---|
| M0 | **Foundations:** Rails app skeleton, `structure.sql` (MySQL), migration setup, tenant transaction helper, mandatory tenant-scope + composite-key conventions, audit writer, outbox + Solid Queue, OpenAPI pipeline, error format, idempotency | CI fails if any tenant-table query lacks the tenant scope; a write produces exactly one audit row and one outbox event in the same transaction | Tenant helper = `CurrentAttributes` + default scopes; audit/outbox rows written in the same ActiveRecord transaction as the domain write |
| M1 | **People spine:** organizations, users, memberships, roles and permissions, dimensions and scopes, people, contact points, companies, affiliations, custom fields, documents with scanning | Matching and merge rules; person visibility under scopes; cross-tenant links are impossible | ActiveRecord models + MySQL full-text + prefix search for matching (Elasticsearch later if usage proves it necessary) |
| M2 | **Pipelines and subjects:** templates, job and project pipelines, overrides, versions, stage interviews, scorecard templates; requisitions, jobs, postings, apply; applications and project members with commands; conversion | The worked example in [`job-pipelines.md`](./job-pipelines.md#worked-example) passes; one transition path serves both subjects | State machines as plain Ruby objects / state-machine gem; commands as service objects |
| M3 | **Configuration as code:** revisions, plan and apply with per-object concurrency, rollback, CLI `pull` · `validate` · `plan` · `apply`, structured if-rule validation | A plan applies, a conflicting UI edit to the same object blocks it, an unrelated edit does not | Thor CLI; rule engine from [If-rules](#if-rules) type-checks and evaluates conditions |
| M4 | **Communications and CRM outreach:** mailbox connections (personal and shared), Gmail send, Gmail sync with push notifications and a history backstop, message templates, the send queue with per-mailbox caps, scheduled messages, sequences and enrollments, timeline | A sequence sends from a recruiter's Gmail, the candidate's reply is synced and stops it, a confirmation goes from recruiting@, and the timeline shows all three | Gmail send/sync via `google-apis-gmail`; Action Mailer for sending; Solid Queue for the send queue with per-mailbox caps |
| M5a | **Interviews, calendars and booking:** Google Calendar connection and delegation, interviewer profiles and pools, holidays and rooms, the availability engine, suggestions and booking with a live re-check, reschedule and cancel, scorecards and the stage guards that need them | A five-interview panel is suggested and booked with a live free/busy re-check | `google-apis-calendar` + delegation; availability engine as service objects |
| M5b | **Candidate scheduling and calendar changes:** self-schedule links and availability requests (public pages), no-calendar invites with `.ics`, calendar push channels and sync (declines replaced from the pool, outside moves flagged), interviewer reminders and scorecard-due nudges | A candidate books a panel from a link; an interviewer's decline is replaced from the pool without anyone re-booking | Public pages as Rails controllers with signed tokens; `.ics` via the `icalendar` gem |
| M6a | **Offers and approvals:** offer fields with reapproval, offers and versions, structured approval policies (first match wins, catch-all), approvers by role, user or dimension attribute, parallel and sequential steps, overrides, rescind | An offer routes to the department head by policy | Policy `when` uses the M3 rule engine |
| M6b | **Letters, sending and acceptance:** offer templates by dimension, generated letters, sending with click-to-accept behind the signature-provider interface, decline and counter-offer, expiry, recorded responses, hire on accept, the hire packet | The routed offer is accepted and hires | Letter generation as Rails views/PDF; click-to-accept behind signed tokens |
| M7a | **Compliance policies and consent:** policies, notices and versions, consent purposes, consent gates on the apply form and on blocked actions, first-outreach notices, evidence | An EU applicant is shown the EU notice in their language and cannot apply without the required consent; a message is blocked until the consent a policy names exists | Consent gates as controller/service guards; notices versioned as records |
| M7b | **Retention, requests, hold, erasure:** retention job and extension requests, data requests and the access packet, legal hold, erasure | Erasing a person leaves no personal data in tables, audit, outbox, timeline or search; a hold blocks it | Erasure as a Solid Queue job with a verification pass; audit rows anonymized, not deleted, where the design rules require evidence without personal data |
| M8 | **Enterprise controls and integrations:** Google sign-in (verified domains, session limits), repository lock and break glass, webhooks, events API, sync tokens, MCP tools, CSV import and export | A CSV export from a typical ATS imports cleanly with field mapping and provenance; a webhook consumer converges on the same state as a sync client | OmniAuth Google; CSV via Ruby stdlib + importer service objects; MCP via the Ruby MCP SDK on the public API |
| M9 | **Web app:** the recruiter app (pipelines, people and their timelines, mail and sequences, scheduling, offers, sourcing), admin settings (including configuration with plan and apply), and the candidate pages (careers page, apply, booking, offer, consent, unsubscribe), all on the public API | The release gate below runs through the web app | Remix 3 (no React); the web app consumes the same API as integrations and the CLI (REST and GraphQL), and holds no business logic |

**Moved to v2** (decided 2026-10-24; sourcing remainder 2026-11-04): hardening (the load test to the [scale targets](./architecture.md#scale-targets-and-production-sizing), the penetration test, SOC 2 controls); CSV migration edge cases ([`decisions.md`](./decisions.md#technical-defaults-signed-off-2026-10-24)); Chrome extension, enrichment partner, SMS/InMail, LinkedIn RSC, job boards, assessments/bg-check marketplace, events/newsletters, and AI helpers ([`sourcing-market-gaps.md`](./sourcing-market-gaps.md)). Google app verification and the CASA assessment are not deferred: they are launch dependencies below.

**M10 (shipped):** sourcing ops P0 plus referrals and openings — see [`progress.md`](./progress.md#m10--sourcing-ops-p0--referrals--openings).

### Release gate

Unchanged — v1 ships when this runs automated, end to end, on every release:

> An organization signs in with Google on its verified domain, applies its configuration from a repository, and imports its people, jobs and applications from CSV. A sourcer adds a prospect to a project and enrolls them in a sequence sent from the sourcer's own Gmail; the prospect's reply is synced from that mailbox, stops the sequence, and the prospect is converted to an application. Interview confirmations go from the shared recruiting mailbox. The application runs through a customized job pipeline with a hiring manager scoped to Engineering in EMEA, a Google-scheduled panel, scorecards, and an offer approved by the department head under policy, then accepted and hired. A webhook consumer and a sync client both end in the same state. Erasing the person afterwards leaves no personal data anywhere the [design rules](./architecture.md#design-rules) name.

## Launch dependencies

Unchanged:

- **Google app verification** for the sensitive scopes (Calendar, `gmail.send`).
- **Google restricted-scope verification and a CASA security assessment** for reading Gmail (`gmail.readonly`), renewed every 12 months. Big Buck stores synced messages, so the assessment applies.
- **Google's Limited Use requirements** for Gmail data: used only to show and act on candidate communication, never for advertising or model training, disclosed in the privacy policy and on the connect screen.

**Demos before verification.** A demo runs without any of the above: the Google Cloud project is owned by Big Buck's own Workspace organization and its OAuth consent screen is set to **Internal**, which Google does not require to be verified. Demo recruiters and the shared mailbox are accounts in that Workspace; candidates and prospects are ordinary recipients at any address. A prospective customer who wants to connect their own Google accounts needs the app in **Testing** status instead: at most 100 allowlisted users, and connections expire after 7 days. Big Buck's own notifications use the demo shared mailbox, so no email provider is needed until launch.
