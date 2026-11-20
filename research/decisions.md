# 32 — Decisions

Product and technical decisions for v1, with dates. The plan they shape is [`build-plan.md`](./build-plan.md); the rules they produced are in [`architecture.md`](./architecture.md#design-rules).

## Founding decisions (2026-10-24)

1. **One platform.** The ATS and the talent CRM are one product on one schema: the same person record, the same pipeline machinery, permissions, events, audit and API. Nothing is synced between two systems, because there is only one.
2. **Enterprise first.** v1 is built for enterprise recruiting teams: SSO and provisioning, scoped permissions, configuration as code, audit, migration from the incumbent ATS, and the [scale targets](./architecture.md#scale-targets-and-production-sizing).
3. **SMB later, as a preset.** The plug-and-play SMB experience comes after v1. It is the same product with a restricted, pre-chosen configuration (owner setup, starter kit, limits), not a separate code path. The design is kept in [`owner-setup.md`](./owner-setup.md).
4. **Sales-led onboarding in v1.** Organizations are provisioned by Big Buck, not by self-serve sign-up. Self-serve, and the trust and safety work it needs (verified company identity, send limits for new tenants, posting review), arrives with the SMB preset.
5. **This repository is the build.** Pitch and business documents were removed; everything here describes what gets built.

## Resolved questions

1. ~~SAML and SCIM: build or buy?~~ Decided 2026-10-24: **Google sign-in is the v1 single sign-on; SAML and SCIM move to v2.** Without SCIM, offboarding relies on Google: sessions are short (re-checked with Google at least daily), and a user whose Google account is suspended or removed loses access at the next check; admins can also deactivate users in Big Buck directly. Identity sits behind an internal interface so SAML (likely through a vendor such as WorkOS) can be added in v2 without touching the domain.
2. ~~Microsoft 365 calendar in v1?~~ Decided 2026-10-24: **Google only for v1** (Calendar, Meet, sign-in). Microsoft 365 stays WIP; the availability engine stays provider-neutral so it can be added without a redesign.
3. ~~Email~~ Decided 2026-10-24: **recruiters send from their own Gmail and from shared company mailboxes, and Big Buck tracks both** ([rule 12](./architecture.md#design-rules)). Reading Gmail uses restricted scopes, so Google's restricted-scope verification and a CASA security assessment by an approved assessor, renewed every 12 months, are v1 launch dependencies. Start both early; the assessment covers the whole service that stores Gmail data, so the security work in [`security.md`](./security.md) feeds it. A transactional provider is still needed, but only for Big Buck's own notifications to users.
4. ~~Importers~~ Decided 2026-10-24: **no vendor-named importers in v1.** Migration is generic CSV with field mapping, behind an importer interface, so a vendor-specific importer can be added later without naming anyone up front.
5. ~~EU region~~ Decided 2026-10-24: **v3 at the earliest.** Region pinning per organization stays in the design.
6. ~~Offers: click-to-accept or e-signature?~~ Decided 2026-10-24: **click-to-accept in v1, behind the `signature_provider` interface**, so DocuSign, Dropbox Sign or another provider plugs in later the same way identity and email providers do ([`offers.md`](./offers.md#acceptance-and-signature)).
7. ~~Scheduling window~~ Decided 2026-10-24: **14 days by default, configurable per organization** ([`scheduling.md`](./scheduling.md)).

## Open decisions

1. **Transactional email provider for Big Buck's own notifications** (to users only, never candidates: "your mailbox needs reconnecting", approval requests, scorecard reminders). Built behind the `Notifier` interface, which writes to the log until this is chosen. Options: Postmark, SendGrid, Amazon SES, Mailgun. Needed before launch; nothing in the build is blocked on it.

## Decided 2026-11-02

13. ~~App API: GraphQL or REST?~~ **Both, over one service layer.** GraphQL (graphql-ruby at `POST /graphql`) becomes the main surface for the Remix app and for agents/MCP, because screens and agents need nested data in one round trip and agents should fetch only the fields they need. REST stays for public candidate pages, OAuth, webhooks out, uploads and the sync feed, and for the SDK/CLI until the schema settles. Both call the same services and every write goes through `ChangeWriter`, so audit and events do not depend on the transport. One schema for every tenant (custom fields as typed values with versioned definitions), command mutations with `expectedVersion`, field-level authorization, committed `schema.graphql` with a breaking-change check in CI, `@deprecated` instead of `/v2`. Replaces decision 10.
14. ~~Agents: user rows or their own table?~~ **Their own `agents` table**, owned by a membership. An agent acts with its scopes intersected with its owner's role, so it never exceeds the person who owns it. Audit records the agent as the actor and the owner as `on_behalf_of`. A signed-in user can act as their own agents. Agents cannot create agents or credentials.
15. ~~Identity transport~~ **Bearer credentials only in production.** Personal, integration, agent and session tokens (`bb_live_` / `bb_sess_`), stored as SHA-256 digests. The `X-Organization-Id` / `X-Actor-Id` headers are a test harness only (`config.x.header_auth`). Google sign-in hands the browser a one-time code, never a token or actor id.
16. ~~Remix look~~ **Light and dark themes are required; the layout stays creative.** One semantic token set with light and dark values; no clone of BigBuck-ATS's sidebar shell.

## Decided 2026-10-25

10. ~~App API: GraphQL or REST?~~ **Superseded 2026-11-02 — see decision 13.** ~~REST only in v1.~~ The recruiter app, admin settings and candidate pages use the same OpenAPI REST contract as the CLI, MCP tools and integrations. No GraphQL in v1. Revisit a read-only GraphQL layer only after the UI proves a real aggregation problem ([`api-strategy.md`](./api-strategy.md#optional-future-graphql)).
11. ~~If-rules: CEL vs a Ruby DSL?~~ **Neither full CEL nor eval'd Ruby.** Conditions are a **closed, structured rule schema in YAML** — one system for stage guards, approval `when`, compliance conditions and automations. Rules are data: fixed operators, fixed field paths, type-checked at `validate`, never `eval`. v1 operators are the comparisons the product already needs (eq/neq, gt/gte/lt/lte, in, and/or/not, dimension “this value or under it”). Grow the operator set only when a real policy needs one. String expression languages (CEL or otherwise) are out of v1; a sugar syntax can be considered later if ops asks for it. Details and example: [`build-plan.md`](./build-plan.md#if-rules) and [`recruiting-as-code.md`](./recruiting-as-code.md#file-format).
12. ~~MySQL tenancy and schema port principles?~~ **Enforce product guarantees with MySQL mechanisms.** Every tenant table carries `org_id`; every query carries the tenant; unset tenant fails closed; composite FKs `(org_id, id)` stop cross-tenant links; isolation is proven in tests each milestone. The database enforces structure; the app enforces visibility and field policy. Bulk work stays in short transactions. Solid Queue may share MySQL — cap workers and watch API latency vs queue lag. Port checklist: [`build-plan.md`](./build-plan.md#mysql-principles).

## Decided 2026-10-24 (later the same day)

8. ~~When the recruiter web app is built~~ **The web app is M9, right after M8**, built on the finished API: the recruiter app, admin settings and the candidate pages. **The old M9, hardening, moves to v2**: the load test to the scale targets, the penetration test and SOC 2 controls. Google app verification and the CASA assessment stay **v1 launch dependencies**, because v1 customers cannot connect Gmail or Calendar without them ([`build-plan.md`](./build-plan.md#launch-dependencies)).
9. ~~Technical defaults~~ **Signed off**, with two changes: agent actions mirror the permissions of the user the agent acts for (no extra always-human list), and the CSV migration edge cases move to v2.

## Technical defaults (signed off 2026-10-24)

| Question | Decision |
|---|---|
| Config file format | YAML only in v1; the manifest is JSON underneath, so other front ends can come later |
| Extra encryption for sensitive fields | Not in v1 beyond Cloud SQL's encryption at rest: OAuth tokens live in Secret Manager, EEO answers in their own schema and role, compensation behind field-level permissions. Revisit application-level encryption with Cloud KMS when a customer requires it |
| Audit history retention | 7 years by default, configurable per organization down to 1 year. Monthly partitions older than 13 months are exported to Cloud Storage (archive class) and dropped from MySQL; exports stay searchable on request |
| What agents may do | **Exactly what the user they act for may do**: an agent credential's permissions are its scopes intersected with that user's role, the same rule as every personal credential. No action is reserved for humans beyond that. Every agent action is recorded with `actor_type = agent` and the delegating user, and organizations limit agents by the scopes they grant |
| CSV migration edge cases | **v2.** v1 imports people, jobs and applications from CSV with field mapping, dry run, provenance and source ids. Deferred: placeholder users for rows whose owner left, importing confidential records as restricted, and full stage histories as `stage_transitions` |

## Defaults taken while building M5 (2026-10-25)

Small choices the specs left open, made so the build could continue. Each is easy to change; say if one is wrong.

| Question | Default |
|---|---|
| Who reads scorecards | Authors always see their own. An interviewer on the application who still owes feedback sees only their own, so others' views cannot colour theirs. Otherwise the job's hiring team and holders of the new `scorecard.read_all` permission (admins and recruiters by default) see every submitted scorecard. Nobody sees another person's draft |
| Loosening the default exit guard | A stage with interviews waits for a submitted scorecard on each **required** interview unless its exit guards include their own `scorecards_submitted`. Marking an interview `required: false` takes it out of the default; `exit: []` does not loosen it |
| When feedback opens | When the interview starts (at once for take-homes, async reviews, provider-run interviews and `scheduling: none`) |
| Panel order | Interviews in a panel run in the order the stage lists them; an "any order" option can come later |
| Load balancing | "Recent load" counts each interviewer's interviews from seven days ago through the end of the search window, so upcoming bookings spread too |
| One interviewer, several panel interviews | Allowed when they don't overlap (buffers respected); the least-loaded free person is chosen each time |
| Reminders | Candidate reminders 24 hours and 1 hour before the first interview of a booking; per-interview and per-job overrides arrive with the per-interview communications settings |
| Interviewer briefings | Sent through the `Notifier` (Big Buck's own notifications), so they wait on open decision 1 for real delivery |
| Interviewer pools in configuration files | API only for now; a pool kind comes with the phase-2 configuration kinds in M8 |
| Interview mail with no coordinator Gmail | Goes from the default shared mailbox rather than waiting |
| Candidate link tokens | The link id signed with Big Buck's key: nothing secret stored, revocation by a column, single use |
| Where candidate links point | The public API until the web app's candidate pages exist (M9) |
| Scorecard-due nudges | Two hours after the end, then daily, for two weeks |
| Which offer fields are compensation | Offer fields classed `sensitive`. They need `offer.view_compensation` to see or set, except for an approver while their request is open |
| Step `mode` | Applies within a step: `parallel` asks every approver at once, `sequential` one after another; steps themselves always run in order |
| Approval policies in configuration files | API only for now; the `ApprovalPolicy` kind comes with the phase-2 kinds in M8 |
| Dimension attributes in conditions | Field paths in structured rules use dotted segments; hyphenated keys are a single path segment (`job.dimensions.level.attributes.salary-max`), never split on `-` |

## Defaults taken while building M6b (2026-10-25)

| Question | Default |
|---|---|
| Hiring and offers | Hiring requires an accepted offer (`hire_requires_accepted_offer`, default on). Hiring on acceptance is off by default (`offers_hire_on_accept`), so a recruiter confirms the hire |
| Offer link expiry | The template's `expires_after_days` (default 7, up to 90), or the `expires_at` given when sending |
| What acceptance records | Version and letter hash, time, IP, browser, the email the link went to and an optional typed name, in an append-only row; plus a stamped copy of the letter |
| Telling the candidate about a rescind | Only when the recruiter asks (`notify_candidate`); the message waits in the outbox to be reviewed |
| A letter missing a value | Refuses to render and names the missing values, rather than sending a blank |
| Letter fonts | Standard PDF fonts for now; a Unicode font is a launch item |

## Defaults taken while building M7a (2026-10-25)

| Question | Default |
|---|---|
| Where a person is | What they say (`country`, `region`), set on the apply form or by a recruiter. Never inferred from an IP address; a policy that needs a location does not match someone who gave none, so they fall to the fallback |
| Country groups | `eu`, `eea`, `uk`, `us`, `ca`, `eu-eea-uk-ch` as shorthand for writing conditions; the company decides which laws apply |
| Nothing configured | With no policy at all the apply form asks nothing and nothing is blocked. Configuration validation (M8) is where a missing fallback is reported |
| Consent given on a form | Points at the first notice shown with it, so the record says what the applicant saw alongside the request |
| Re-notifying | `immediately` behaves as `on-next-contact` until Big Buck sends its own notice emails |
| Policy endpoints | `/compliance-policies` (like `/approval-policies`) rather than `/compliance/policies` |
| Blocked actions in v1 | `sequence.enroll` and `communication.send` |
| Event for a blocked action | `compliance.action_blocked` is not emitted yet: the refusing transaction rolls back, so the event needs a separate write path (M8, with the events API) |

## Defaults taken while building M7b (2026-10-25)

| Question | Default |
|---|---|
| What erasure leaves | An empty person row (no name, contact details, location or reference), do-not-contact on, with their applications and history intact. A row with no personal data is not personal data, and reports and foreign keys need it |
| `anonymize` or `delete` | Both clear everything that identifies the person. `delete` also removes messages, enrollments and scorecards; `anonymize` keeps them with their text cleared, for aggregate reporting. Erasure requests default to `delete` |
| What is kept on purpose | The do-not-contact address list (a person who opted out must never be written to again, and that needs the address), consent and receipt rows without network details (proof of what was agreed), and audit history (keyed hashes only). Erasure results list them |
| What counts as activity | A change to their applications, a message to or from them (not our own extension request), a granted consent, an edit to their profile, or an extension recorded by a recruiter. Their application going stale is not enough while it is still open |
| Who retention never touches | People with an open application, employees, and records merged into someone else (the survivor is judged) |
| Asking before acting | If the rule has an extension request and the person has an email address, the request goes out `send_before` the date, and Big Buck waits at least a day after it. No email address, no request |
| Answering an extension request | A reply to the email counts as activity, or a recruiter records it (`POST /people/{id}/retention-extension`). A public link to extend arrives with the candidate pages (M9) |
| `review` | Queues the person; a person with `data_request.manage` and `person.erase` decides keep, anonymize or delete |
| Data request due date | `respond_within` of the highest-priority policy that sets it, else 30 days |
| Access packet | Everything held about the person except interviewer scorecards and offer compensation, which are the company's call to share; the packet says so |
| Erasure needs storage | Erasing deletes files, so the API refuses (503) when document storage is not configured, rather than leaving files behind |
| Search | There is no search index yet. When there is, erasure must clear it; the inventory test is where to add it |
