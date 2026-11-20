# 33 — Progress

Active build: Rails + MySQL ([`build-plan.md`](./build-plan.md)).

| Milestone | Status |
|---|---|
| M0 Foundations | Built |
| M1 People spine | Built |
| M2 Pipelines and subjects | Built |
| M3 Configuration as code | Built |
| M4 Communications and CRM outreach | Partial: tables, services and REST exist; real mail, sequence authoring and the CRM record are in the CRM stack (C1–C14) |
| M5a Interviews, calendars and booking | Built |
| M5b Candidate scheduling and calendar changes | Built |
| M6a Offers and approvals | Built |
| M6b Letters, sending and acceptance | Built |
| M7a Compliance policies and consent | Built |
| M7b Retention, requests, hold, erasure | Built |
| M8 Enterprise controls and integrations | Built |
| M9 Web app | Built |
| Hardening | v2 |
| Product gap wave (REST↔UI) | Built — [`product-gap-build-plan.md`](./product-gap-build-plan.md) |
| OpenAPI → MCP server | Built — [`../mcp/README.md`](../mcp/README.md) |
| OpenAPI → SDK + CLI (setup/ops) | Built — [`../sdk/README.md`](../sdk/README.md), [`../cli/README.md`](../cli/README.md) |

## M9 — Web app

- Remix 3 thin client in `web/` over the same `/v1` REST API (no business logic in the frontend).
- Recruiter: people (+ timeline Frame / send), jobs (+ pipeline board), pools, sequences, applications (scorecards + panel book), offer lifecycle, scheduling links, careers branding, admin (companies/events/webhooks).
- Candidate: careers hero, apply, public offer accept/decline, public scheduling link status.
- Rails expansions: projects, sequences, scorecards, companies, events/sync, webhooks, sessions, people erase; see [`api-ui-parity.md`](./api-ui-parity.md).

## MCP

- `mcp/` generates tools from `openapi/openapi.yaml` (`operationId` names) and proxies to `/v1`.
- Auth is an agent bearer token (`BIGBUCK_TOKEN`); the organization comes from the token. Writes require `BIGBUCK_MCP_ALLOW_WRITES=true`; calls send `X-Bigbuck-Surface: mcp`.

## SDK + CLI

- `@bigbuck/sdk` — thin `/v1` client (people, jobs, applications, projects, sequences, config plan/apply, CSV imports).
- `@bigbuck/cli` (`bigbuck`) — company setup (`config init/plan/apply`, `import csv`) and recruiter ops verbs; channel only (web/MCP stay direct).
- `POST /v1/imports` exposes `CsvPeopleImporter` for people CSV with dry-run and field mapping.

v1 milestones M0–M10 are complete. Product gap, MCP, and the SDK/CLI channel close platform holes toward the release gate. Google app verification / CASA remain launch dependencies.

## M10 — Sourcing ops (P0 + referrals + openings)

Partly shipped against [`sourcing-market-gaps.md`](./sourcing-market-gaps.md). The data model, services and REST endpoints below exist; a recruiter cannot yet run a week of sourcing on them. The CRM stack (C1–C14) adds the mail transport, send queue and opt-outs, notes/tags/tasks, search, sequence editor, reporting and the sourcing agent:

- People search filters, saved searches, bulk enroll / DNC
- Sequence shared + template flags, bulk enroll, task steps → sourcing tasks
- Job rediscovery (past applicants / silver medalists)
- Funnel + sourcing analytics APIs and Remix `/analytics`
- Contact cooldown org setting + company/domain DNC lists
- Referrals with referrer attribution
- Requisitions / openings with headcount and job link

## v2 (paused)

| Item | Notes |
|---|---|
| Hardening | Load test to scale targets, penetration test, SOC 2 controls |
| SAML / SCIM | Identity beyond Google Workspace SSO |
| SMB preset / self-serve | Same product, restricted config ([`owner-setup.md`](./owner-setup.md)) |
| CSV migration edge cases | Placeholder users, confidential import, full stage histories |
| Chrome extension | LinkedIn capture into CRM |
| Email enrichment partner | Metered lookups; no owned talent graph |
| SMS / InMail channels | Multi-channel sequences |
| LinkedIn RSC, job boards, assessments/bg-check | Partner-gated Planned items |
| Events / newsletters | Attraction beyond 1:1 sequences |
| AI helpers | Drafts / ranking over our data only; not an interviewer |
