# 24 — v1 Scope

## Decisions

Revised 2026-10-24, replacing the "two demos" scope of the same morning.

1. **One enterprise platform for the ATS and the talent CRM.** Hiring and sourcing share one schema, one person record, one pipeline machinery, one permission model, one event stream and one API. The build is described in [`build-plan.md`](./build-plan.md).
2. **Enterprise first.** v1 is built and judged as an enterprise product: SSO and provisioning, scoped permissions, configuration as code, audit, migration, and the scale targets in [`architecture.md`](./architecture.md#scale-targets-and-production-sizing).
3. **The SMB demo comes later, as a restricted preset.** It is the same product with defaults chosen for the owner, limits, and a short setup ([`owner-setup.md`](./owner-setup.md)). It adds no separate code path, so building it later costs configuration and onboarding work, not a second product.
4. **Sales-led onboarding.** v1 organizations are provisioned by Big Buck. There is no self-serve sign-up until the SMB preset, which brings its own trust and safety requirements.
5. **The AI interviewer is out.** Big Buck builds the rails any interview provider or agent plugs into: the `external` interview format, scoped agent credentials, events.
6. **Agent-ready and scalable rails.** Every capability is in the public API, safe for agents to call, and built to run on one shared deployment at the targets in [`architecture.md`](./architecture.md#scale-targets-and-production-sizing).
7. **Integrations are labelled honestly.** Each shows its real status; v1 promises only what is built.
8. **Compliance: Big Buck supports, the company owns.** Big Buck enforces whatever policies a company configures; the company decides them ([`consent-and-compliance.md`](./consent-and-compliance.md)).
9. **Fraud detection is out of v1.** The public endpoints keep basic protections ([`architecture.md`](./architecture.md#design-rules), rule 13).

## The product in v1

| Area | What an enterprise customer gets |
|---|---|
| **Access** | Google sign-in on the company's verified domain (SAML and SCIM in v2); custom roles; every setting a permission; scopes that combine dimensions ("Engineering in EMEA"); field-level visibility for compensation and sensitive data |
| **Structure** | Their own dimensions (department, discipline, level, region, anything) with attributes, driving access, reporting, template defaults, approvals and variables |
| **Hiring** | Requisitions, jobs, postings and careers pages; per-job pipelines built from templates with one-off edits and locked stages; interviews inside stages; scorecards; reject, withdraw and hire as commands |
| **Sourcing (CRM)** | One person record across prospect, candidate, employee and alumni; companies and work history; projects (talent pools) with their own pipelines; outreach sequences sent from each recruiter's own Gmail; replies synced from the mailbox; conversion to an application with attribution |
| **Scheduling** | Google Calendar and Meet with domain-wide delegation; interviewer pools, load limits and panels; self-scheduling and coordinator scheduling; automatic replacement when an interviewer declines |
| **Offers** | Offer fields with versions, approval policies by department and level, compensation visibility, letter templates, click-to-accept with evidence |
| **Communications** | Mail sent from recruiters' own Gmail and shared company mailboxes (such as recruiting@), both synced; templates per message type, office and language; scheduled sends; reminders; one message history per person |
| **Compliance** | Company-authored policies per jurisdiction, notices, consent evidence, retention, data requests, legal hold, complete erasure |
| **Change control** | Configuration as files with plan and apply, rollback, a GitHub workflow, repository lock and break glass |
| **Platform** | REST API with dated versions; MCP tools and SDK/CLI OpenAPI catalog generated from the contract; GraphQL for the web app and agents; events API, signed webhooks, incremental sync, sandbox organizations |
| **Migration** | Generic CSV import and export with field mapping and dry run; vendor-specific importers can be added later behind the same interface |

## Agent-ready rails

Agents (a company's own, or a vendor's) use exactly the same surface as people and integrations.

| Property | How |
|---|---|
| One contract | Every action is in the OpenAPI document; the MCP server's tools are generated from it ([`api-strategy.md`](./api-strategy.md)) |
| Scoped identity | Agent credentials carry scopes like any integration, act for a delegating user, and are recorded as `actor_type = agent` |
| Same permissions as people | An agent can do exactly what the user it acts for can do, within the scopes its credential was granted; every action is recorded as an agent action (decided 2026-10-24, [`decisions.md`](./decisions.md#technical-defaults-signed-off-2026-10-24)) |
| Retry-safe | `Idempotency-Key` on every write; commands are idempotent |
| Observable | Every change is an event; `GET /events` replays 30 days |
| Previewable | Configuration changes have `plan` before `apply`; scheduling and offers have dry-run endpoints |
| Bounded | Per-credential rate limits and per-tenant quotas, reported in headers |
| Pluggable work | Interview providers and assessment vendors connect through the provider contract (`format: external`, [`job-pipelines.md`](./job-pipelines.md#interviews-inside-stages)) |

## Integrations

Status labels used everywhere (docs and product): **v1** (built and supported), **WIP** (in development, no date promised), **Planned** (designed, not started).

| Integration | Status | Notes |
|---|---|---|
| Google sign-in (OIDC) | v1 | The v1 single sign-on, limited to the organization's verified Workspace domains |
| SAML SSO | Planned (v2) | Okta, Microsoft Entra ID and other identity providers |
| SCIM user provisioning | Planned (v2) | Automatic create, update and deactivate from the identity provider |
| Google Calendar and Google Meet | v1 | Sensitive scopes: Google app verification must finish before launch ([`scheduling.md`](./scheduling.md)) |
| Gmail: send from recruiters' and shared mailboxes | v1 | `gmail.send`, a sensitive scope: Google app verification |
| Gmail: sync replies and threads | v1 | `gmail.readonly`, a restricted scope: restricted-scope verification and a CASA assessment every 12 months are launch dependencies ([`build-plan.md`](./build-plan.md#launch-dependencies)) |
| CSV import and export | v1 | |
| Webhooks, events API, MCP server | v1 | |
| Microsoft 365 calendar and Teams | WIP | Google only for v1 (decided 2026-10-24) |
| Vendor-specific importers | Planned | Not named or promised in v1; generic CSV covers migration |
| Outlook mailboxes (send and sync) | WIP | Google only for v1 |
| Zoom | WIP | |
| Slack notifications | WIP | |
| E-signature (DocuSign, Dropbox Sign, Adobe Acrobat Sign) | WIP | v1 has click-to-accept with an audit trail, behind the same `signature_provider` interface ([`offers.md`](./offers.md#acceptance-and-signature)) |
| HRIS hand-off (Rippling, BambooHR, Workday) | WIP | v1 offers the hire packet by API and event |
| LinkedIn (Recruiter System Connect) | Planned (v2) | Partner-gated, all-or-nothing, requires historical backfill and 30-day purges |
| Chrome extension (LinkedIn capture) | Planned (v2) | Sourcer daily driver; no talent graph |
| Email / phone enrichment partner | Planned (v2) | Metered lookups; partner, not owned data |
| Job boards (Indeed and others) | Planned (v2) | |
| Background checks (Checkr and others) | Planned (v2) | |
| SMS and WhatsApp | Planned (v2) | The message model already has a `channel` field |
| Identity verification | Planned (v2) | Part of fraud work, out of v1 |

## Out of v1

| Item | Why | What v1 does instead |
|---|---|---|
| SMB preset, owner setup, self-serve sign-up | Enterprise first | Big Buck provisions organizations; setup design kept in [`owner-setup.md`](./owner-setup.md) |
| AI helper endpoints (resume parse, summaries, outreach drafts) | Not on the build path | Kept in the API design as later; external providers plug in through the rails |
| AI interviewer | Not Big Buck's product | Provider contract so any vendor's interviewer or assessment plugs in |
| Fraud and deepfake detection | Hard, and pulls toward biometrics that carry legal risk | Bot challenge, per-posting and per-IP limits, duplicate detection through contact points |
| Full candidate portal | Large surface | Secure single-purpose links: scheduling, availability, offers, consent, data requests |
| Native legally binding e-signature | Needs signing evidence, certificates and legal review | Click-to-accept with audit trail; e-signature providers are WIP |
| Interview holds and debrief scheduling | Second-order scheduling features | Coordinator tasks |
| EU region | v3 at the earliest | Region pinning per organization is designed, deployment later |
| Load test, penetration test, SOC 2 controls | v2 (decided 2026-10-24) | Built to the scale targets; Google verification and CASA still happen before launch |
| CSV migration edge cases | v2 | Placeholder users, restricted import of confidential records and full stage histories come later |
