# Competitor Deep Dive — How ATS/CRM Leaders Are Built

Scope: Ashby, Gem, Greenhouse, Lever, plus the enterprise CRM-first players (Beamery, Eightfold, Phenom).
Goal: decide what to copy for a **unified ATS + CRM** with a flexible data model and API.

**Evidence quality:** Vendor docs were only partly readable. Ashby's API index and Lever/Greenhouse integration guides were good. Gem's endpoint reference was not retrievable (it is an OpenAPI 3.0.2 spec at `api.gem.com/v0/reference`). Beamery/Eightfold/Phenom schema detail is not public; only positioning was found. Items marked *(verify)* need a primary-source check before we rely on them.

---

## 1. Per-vendor findings

### Ashby — the closest model to copy
- **One product, one record:** ATS, scheduling, CRM/sourcing and analytics in a single platform. Switching reasons cited most often: native analytics and dropping point tools (Calendly, DocuSign, sourcing tools). Vendor/blog sources, so directional.
- **API style:** RPC-style `POST /category.method` (e.g. `candidate.list`), JSON body, Basic auth with API key. Not REST, not GraphQL.
- **Object surface is broad and uniform:** Candidate, Application, Job, Opening, Job Posting, Interview Plan/Stage/Schedule/Event, Offer, Approval, Custom Field, Source, Hiring Team, **Sequence, Sequence Template, Project**, Report, Audit Log, Webhook, User, File.
- **CRM is native, not bolted on:** Projects (talent pools) and Sequences are first-class objects in the same API as applications.
- **Incremental sync is a core convention:** list endpoints take a `syncToken` and return only records changed since the last sync, plus `createdAfter`; cursors for sub-lists.
- **Custom fields:** typed, attachable to candidates, applications, jobs, openings, offers, employees, projects and archive details. They added an *Employee* field type that links to a record instead of free text, because reporting needed referential integrity. Archive reasons are structured custom fields.
- **Webhooks:** per-object event types (candidate, application, job, offer, interview schedule, etc.), a `ping` event, retries, create/update/delete management endpoints.
- **Weak spots reported:** learning curve, smaller integration catalog than Greenhouse.

### Gem — CRM-first, ATS added
- **Three separate APIs:** CRM (candidates, projects, sequences, users), ATS (jobs, applications, offers), Job Board. API key in `X-API-Key`, versioned `/v0/`, OpenAPI 3.0.2 spec.
- **Product concepts:** Projects (one per open role, group candidates), Sequences (staged outreach until reply), Talent Pools/Communities, rediscovery of silver medalists and past applicants, unified activity feed (email, InMail, texts, interviews, notes).
- **Positioning:** one source of truth per candidate relationship; works on top of *other* ATSs via real-time bidirectional sync, and now offers its own ATS.
- **Lesson:** three API surfaces is a symptom of the CRM and ATS being built separately. Their sync problem is exactly what we avoid by building one record.

### Greenhouse — the incumbent integration ecosystem
- **Harvest API v1/v2 retire Aug 2026; v3 uses OAuth 2.0** and cursor pagination (cursor must be the only query param; opaque; only `rel="next"`). Integrators report silent failure modes: filters dropped on cursor pages, 422s misread as end-of-data, stored cursors breaking.
- **No direct get-by-ID in v3 per one connector's migration notes** (use search with an ID list) *(verify)*.
- **Strengths to copy:** structured hiring (scorecards, interview kits), the largest integration marketplace. **To avoid:** forced breaking migration, silent pagination traps, API-key-to-OAuth cliff.

### Lever — candidate-centric, with real CRM history
- **Model:** Contact (a unique person) → Opportunity (a candidacy, the primary object) → Application (posting-specific). Lever deprecated `/candidates` in favor of `/opportunities` + `contact`.
- **This is the right shape for unified ATS+CRM:** a person exists independently of any application; pipeline entries hang off them.
- **API limits:** 10 req/s steady, 20 burst, **application POSTs capped at 2/s** (risk of dropped applicants), offset-token pagination with no total counts, webhook signature in the body rather than a header, silent webhook disabling after repeated failures, rotating one-hour OAuth tokens that race across workers.
- **Lesson:** every one of those is a thing integrators complain about. Do the opposite.

### Beamery / Eightfold / Phenom — enterprise talent CRM
- Public sources show positioning only: Beamery = CRM roots plus skills/workforce intelligence; Eightfold = skills inference and matching; Phenom = suite (career site, CRM, mobility), HCM-heavy integrations. No schema or API detail found. Gem explicitly positions against Beamery and Phenom as needing big implementation teams.
- **Lesson:** the enterprise tier sells skills graphs and matching. That is a later layer; the mid-market winner is Ashby/Gem-style simplicity.

---

## 2. Patterns worth copying

| # | Pattern | From | Why |
|---|---|---|---|
| 1 | **Person is separate from application** (Contact/Candidate → Application) | Lever | One record serves both CRM and ATS; no duplicate people |
| 2 | **Projects/pools and sequences as first-class objects in the same API** | Ashby | CRM and ATS share auth, permissions, audit, search |
| 3 | **`syncToken` incremental sync on every list endpoint** | Ashby | Makes integrations and warehouses cheap and correct |
| 4 | **Typed custom fields on every object, with reference types** | Ashby | Reporting stays queryable; avoids free-text drift |
| 5 | **Structured archive/reject/close reasons** | Ashby | Analytics quality |
| 6 | **Webhooks per object event, `ping`, signature in header, never silently disable (alert instead)** | Ashby, fix Lever | Reliability |
| 7 | **OpenAPI spec published from day one** | Gem | Generates SDKs, CLI, MCP tools |
| 8 | **Structured hiring: scorecards, interview kits** | Greenhouse | Compliance and quality; our `scorecards` table covers it |
| 9 | **Unified activity timeline per person** (email, notes, interviews, stage changes) | Gem | The thing that makes CRM+ATS feel like one product |
| 10 | **Native analytics on the same data** | Ashby | Top reason teams switch |
| 11 | **Rediscovery: surface past applicants/silver medalists for new reqs** | Gem | Only possible with one record |

## 3. Pitfalls to avoid

- Separate CRM and ATS APIs/records that need syncing (Gem's current architecture).
- Breaking API version retirements with credential-model changes (Greenhouse v3).
- Pagination that fails silently; opaque cursors with undocumented interaction rules.
- Hard low limits on candidate-submission endpoints (Lever 2/s).
- Auth that is awkward for multi-tenant integrators (Lever rotating tokens).
- Free-text custom fields that can't be reported on.

---

## 4. Should we start with GraphQL?

**Recommendation: no. Start with REST + OpenAPI, plan for a GraphQL read layer later.** None of the four leaders ships GraphQL as its primary API (Ashby: RPC-over-POST; Gem: REST/OpenAPI; Greenhouse and Lever: REST). The reasons in `api-strategy.md` still hold, and the unified model adds two points:

1. **ATS+CRM is command-heavy** (move stage, enroll in sequence, add to project). Explicit verbs map cleanly to REST, CLI and MCP.
2. **Field-level permissions** (`permissions.md`) plus custom fields make GraphQL authorization the hardest part to get right early.

**Where GraphQL does earn its keep here:** the person profile page (person + applications + project memberships + sequence status + timeline in one round trip) and ad-hoc reporting. Plan it as a **read-only GraphQL BFF over the same domain services**, added when the UI shows real over/under-fetching. Design REST resources so a graph can be layered on without schema changes.

**Non-negotiables from the competitor review:** cursor pagination with a documented, stable contract and total counts on request; `updated_since`/sync token on every list; idempotency keys on writes; signed webhooks with the signature in a header; high submission rate limits; OAuth2 client-credentials plus scoped API keys from day one.

---

## 5. Implications for our data model (unified ATS + CRM)

Added to `data-model.md` and `db/structure.sql`:

1. **`people`** (rename/extend `candidates`): the single person record. Contact methods, source, owner, lifecycle (`prospect → candidate → employee/alumni`), do-not-contact flags.
2. **`applications`** stay as-is, linked to `people`.
3. **`projects`** (talent pools) and **`project_members`** (person ↔ project with status, owner, added-by, source).
4. **`sequences`, `sequence_steps`, `sequence_enrollments`, `sequence_events`**: steps are email/task/wait; enrollment tracks state per person; stops on reply or application.
5. **`communications`** gains channel, thread, direction, sync-account; backs the unified timeline.
6. **`tasks`/`reminders`** per person and per project.
7. **Custom objects layer:** `object_definitions` + relation fields, with `custom_field_values` allowing reference types (person, user, job, org).
8. **Sync primitives:** per-table `updated_at` index + monotonic `sync_version` so `sync_token` is cheap.
9. **`timeline_events`** read model fed from the outbox for the person feed.

## 6. Suggested next steps

1. ~~Write the CRM schema (items 1–6).~~ Done 2026-10-24: items 1–9 are designed in [`data-model.md`](./data-model.md) and implemented in [`db/structure.sql`](../db/structure.sql).
2. Draft the OpenAPI spec for people, applications, projects, sequences, webhooks. The contract it must follow (conventions, commands, sync, events) is now in [`api-strategy.md`](./api-strategy.md).
3. Get a free Ashby sandbox and Gem demo, and pull the real OpenAPI for Gem and Ashby's `llms.txt` pages to verify the *(verify)* items.
4. Product gap scoring against 2026 sourcing tools (not just API shape) is in [`sourcing-market-gaps.md`](./sourcing-market-gaps.md).

## Sources
- [Ashby API introduction](https://developers.ashbyhq.com/docs/introduction), [Ashby API index](https://developers.ashbyhq.com/llms.txt), [Ashby custom field update](https://www.ashbyhq.com/product-updates/employee-custom-field-types), [Ashby vs Greenhouse](https://ashbyhq.com/compare/ashby-vs-greenhouse)
- [Gem developer platform](https://api.gem.com/), [Gem CRM API](https://api.gem.com/v0/reference), [Gem CRM product](https://www.gem.com/product/crm), [Gem admin guide](https://help.gem.com/external/admins-getting-started-guide)
- [Greenhouse Harvest v3 overview](https://learn.greenhouse.io/harvest-v3-api-migration-overview), [v3 pagination failure modes](https://dev.to/flarecanary/greenhouse-harvest-v1v2-retires-august-31-three-silent-failure-modes-during-your-v3-cursor-6cl), [Workato v3 migration](https://docs.workato.com/connectors/greenhouse/migration)
- [Lever API engineering guide (Truto)](https://truto.one/blog/how-to-integrate-with-the-lever-api-2026-engineering-guide.md)
- [Beamery vs Phenom](https://pipeline.zoominfo.com/sales/phenom-vs-beamery), [Greenhouse vs Lever vs Ashby](https://www.outsail.co/post/greenhouse-vs-lever-vs-ashby)
