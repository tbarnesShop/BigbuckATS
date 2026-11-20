# BigBuck ATS — Developer Reference

ATS + talent CRM. One product, one schema — Rails API + MySQL + Remix 3 (milestones M0–M10).

The interactive lab at `/session` explores the same system through UI, MCP, API, and CLI. Public developer docs live at `/docs`; ordinary sign-in is `/session/login`. See [local lab setup and verification](./LOCAL_LAB.md) for the pnpm workflow and sandbox lifecycle.

API/CLI authentication uses an external OAuth/OIDC provider. See [OAuth setup and rollout](./OAUTH.md) for provider-neutral PKCE login, service credentials, tenant bindings, and revocation.

UI baseline: [BigBuck design standard](./DESIGN.md) — branding, typography, shared components, page layouts, and interaction rules for docs, lab, and recruiter pages.

## Stack

- **API:** Ruby on Rails (API-only) on Cloud Run
- **DB:** MySQL (Cloud SQL), `structure.sql`
- **Jobs:** Solid Queue (MySQL)
- **Contract:** OpenAPI (`openapi/openapi.yaml`) — app, CLI, MCP, integrations; GraphQL for the web app and agents
- **Frontend:** Remix 3 over the same API (REST + GraphQL)

Plan / progress: [`research/build-plan.md`](./research/build-plan.md) · [`research/progress.md`](./research/progress.md).  
v2 pause list (extension, enrichment, SMS, hardening, SAML/SCIM, …): [`research/progress.md`](./research/progress.md#v2-paused).

## Local setup

Use Node 24 and pnpm 10.34.5 for all JavaScript packages. Each package pins pnpm and keeps a `pnpm-lock.yaml`; install with `--frozen-lockfile`.

```bash
# MySQL 8.4 or 9.7 with databases bigbuck_development / bigbuck_test
# and user bigbuck / bigbuck (see config/database.yml)

bundle install
bin/rails db:prepare
bin/rails test
bin/rails tenant:check
bin/rails server
```

Web (Remix 3):

```bash
cd web
pnpm install
# RAILS_API_URL (default http://127.0.0.1:3000); SESSION_SECRET in production
pnpm run dev
# sign in at /session (demo email sign-in is on in development)
```

### Careers sites

Public careers is `/careers?slug=<organization-slug>`. Employee opportunities are
at `/careers/internal` and require a signed-in, active organization member. Agent
and integration identities cannot use internal careers. Each job's Settings tab
controls its careers audience (`public`, `internal`, `both`, or `hidden`) and
publication. Newly created jobs have no published posting until explicitly published.
Both sites list only active, non-confidential jobs with a published posting.
Internal applications use the member's verified name and email and feed the same
job pipeline. Internal pages use private/no-store caching and noindex headers.

### Identity

Every API call authenticates with a bearer credential: `Authorization: Bearer bb_…`. The
credential decides the organization and who is acting. `X-Organization-Id` / `X-Actor-Id` are
a test-only harness and are ignored in production.

| Credential | Prefix | Acts as | Permissions |
|---|---|---|---|
| Session | `bb_sess_` | the signed-in user | the user's role (12 h; 2 h for demo sign-in) |
| Personal | `bb_live_` | a user | scopes ∩ the user's role |
| Agent | `bb_live_` | an agent, on behalf of its owner | agent scopes ∩ owner's role |
| Integration | `bb_live_` | the organization | exactly its scopes |

Create an agent and its token (`POST /v1/agents`, `POST /v1/agents/{id}/credentials`), then give
the token to MCP, the CLI or the SDK as `BIGBUCK_TOKEN`. A signed-in user can act as one of their
own agents with `X-Bigbuck-Act-As-Agent: <agent id>`. Audit rows record the agent as the actor,
the owner as `on_behalf_of`, the credential and the surface (`X-Bigbuck-Surface`).

MCP (tools from OpenAPI → `/v1`):

```bash
cd mcp
pnpm install
pnpm run generate && pnpm test
# BIGBUCK_TOKEN=bb_live_… BIGBUCK_API_URL=http://127.0.0.1:3000 pnpm exec tsx src/server.ts
```

See [`mcp/README.md`](./mcp/README.md).

SDK + CLI (company setup & recruiter ops channel; `bigbuck api` reaches every OpenAPI `operationId`):

```bash
cd sdk && pnpm install && pnpm test && pnpm run build
cd ../cli && pnpm install && pnpm test
# BIGBUCK_TOKEN=bb_live_… pnpm exec tsx src/cli.ts whoami
# pnpm exec tsx src/cli.ts api list --q people
# pnpm exec tsx src/cli.ts config init --preset recruiting-team
```

See [`sdk/README.md`](./sdk/README.md) and [`cli/README.md`](./cli/README.md).

Big Buck test dataset (100 people + staff user profiles / interviewer pools / hiring teams):


```bash
bin/rails db:seed          # or: bin/rails big_buck:seed
bin/rails test test/integration/big_buck_dataset_e2e_test.rb
cd web && pnpm test         # includes Playwright UI e2e
```

See `test/datasets/README.md`.

Health: `GET /v1/health`

### GraphQL

`POST /graphql` serves the web app and agents (decision 13); REST stays under `/v1` for public
pages, OAuth, webhooks, uploads, sync and the SDK/CLI. Both use the same credentials, permissions
and services, and every write goes through `ChangeWriter`.

- One schema for every organization; the contract is the committed `schema.graphql`
  (`bin/rails graphql:schema:dump`; a test fails when it is stale).
- Fields and mutations declare the permission they need; people follow the same visibility rules
  as REST; confidential jobs need `job.read_confidential`. Hidden objects resolve to `null`.
- Mutations are commands (`moveApplicationStage`, `rejectApplication`) that take `expectedVersion`
  and return `userErrors` (`stale_version`, `invalid_transition`, …) for the caller to act on.
- Limits: depth 12, complexity 400 for registered queries and 200 for ad hoc ones, page size up to
  100, `GraphQL::Dataloader` batching. Browser sessions may only run registered queries
  (`app/graphql/persisted_queries.json`, sent as `{ "id": "<sha256>" }`).

### Compliance

- Erasure (`POST /v1/people/:id/erase` or a completed erasure request) now also clears custom field
  values (all in `delete` mode, `pii`/`sensitive` in `anonymize`), deletes uploaded files, blanks
  the raw CSV in import rows, and drops cached API responses that mention the person. Its residual
  check covers each of these.
- Data-subject requests: `GET/POST /v1/data_requests`, `POST /v1/data_requests/:id/complete`
  (access returns the access packet; erasure erases, and legal holds refuse) and `/reject`. The due
  date follows the person's policy (`dataRequests.respondWithin`, default 30 days).
- `GET /v1/people/:id/access_packet` (needs `person.export`, audited), `GET/POST
  /v1/people/:id/consents` (append-only), `GET/POST /v1/legal_holds`, `POST
  /v1/legal_holds/:id/release`.
- GraphQL: `Person.consents`, `dataRequests`, `legalHolds`, and the mutations `openDataRequest`,
  `completeDataRequest`, `recordConsent`, `placeLegalHold`, `releaseLegalHold`.

### Custom fields (versioned)

Customization never breaks stored data:

- Definitions are archived, never deleted; every change writes a `custom_field_versions` row with
  the full definition, and every value records the `field_version` it was written under.
- Values are validated and stored by type (`text`, `long_text`, `email`, `url`, `phone`, `number`,
  `currency`, `date`, `boolean`, `select`, `multi_select`, `reference`).
- Options still used by values cannot be removed. Changing a field's type is a migration: preview
  the counts, then convert with `on_unconvertible: refuse` (default, changes nothing) or `clear`
  (clears those values and records their ids on the version).
- One GraphQL schema serves every organization: `customFields` returns the `CustomFieldValue`
  interface with typed implementations; `visibility_roles` limits who sees a field.
- Config-as-code now applies: `CustomField` (key `person.<field>`) and `PipelineTemplate` documents
  create and change real configuration, with type-change impact shown in the plan. Other kinds are
  stored as before.
- REST: `/v1/custom_fields` (+ `archive`, `restore`, `type_change` with `dry_run`) and
  `PUT /v1/custom_field_values`.

### Background work

`bin/jobs` runs Solid Queue and the schedule in `config/recurring.yml`:

| Job | Every | Does |
|---|---|---|
| `RelayOutboxJob` | 10 s | The one outbox consumer: fans events out into webhook deliveries (`FOR UPDATE SKIP LOCKED`) |
| `DeliverWebhooksJob` | 30 s | Sends due deliveries; exponential backoff up to 8 attempts; refuses private/metadata addresses; no redirects |
| `AdvanceSequencesJob` | 5 min | Resumes enrollments whose `wait` step is over (`{ "type": "wait", "days": 3 }`) |
| `ExpireOffersJob` | 15 min | Expires sent offers past their acceptance window |
| `ScorecardNudgeJob` | hourly | Reminds interviewers with overdue scorecards (`Notifier`, log-based until a provider is chosen) |
| `RunRetentionJob` | daily | Applies compliance retention to every person (holds, open applications and employees respected) |
| `PurgeIdempotencyKeysJob` | daily | Deletes idempotency keys (and their cached responses) after 24 h |
| `CleanContactPointsJob` | weekly | Re-keys emails/phones/URLs with current rules; collisions become merge suggestions |

CSV imports stage rows with bulk inserts, then apply them in chunks of 500, each in its own
transaction. Imports over 500 rows (or `async: true`) return `202` and run in `ProcessImportJob`;
poll `GET /v1/imports/:id` for `processed_count`. Phones are normalized to E.164 where the number
allows (10 digits default to +1).

### Contracts

- `openapi/openapi.yaml` documents every `/v1` route and nothing else (`OpenapiContractTest`).
- `schema.graphql` must match the code (`SchemaDumpTest`) and may only change additively: CI
  compares it with the PR base and fails on breaking changes unless the removed field was
  already `@deprecated` (`web/scripts/schema-breaking.ts`).
- Web operations and MCP curated tools are validated against `schema.graphql`; generated types
  and the persisted-query manifest must be current.
- Deploy order: Rails first (it carries `app/graphql/persisted_queries.json`), then the web app.

### Audit

- Every tenant write leaves an `audit_events` row: domain changes through `ChangeWriter`, and any
  other model save through the `AuditTrail` concern. Rows name the actor, the user an agent acted
  for, the credential, the surface and the dated API version.
- `audit_events` is append-only, enforced by MySQL triggers. Only a demo reset may purge, with
  `SET @bigbuck_audit_purge = 1`. In production, also grant the app user `SELECT, INSERT` only on it.
- Values are redacted by the column's class in `config/data_classes.yml`: `pii` and `sensitive`
  become an HMAC keyed by `AUDIT_HASH_KEY` (or derived from `secret_key_base`) and salted by
  organization, `secret` never reaches history, `internal` is kept as-is, and custom field values
  follow their field's class. A new column with no class fails tests until it gets one.
- Each request logs one JSON line (org, actor, agent, credential, surface, route, status, timing),
  never params or bodies.
- Triggers need `log_bin_trust_function_creators=1` on MySQL with binary logging (set the Cloud SQL
  flag; MySQL deprecates it but 9.7 still honours it), and `db/structure.sql` is dumped without `DEFINER` clauses.

## Launch wiring

### API (Cloud Run + Cloud SQL MySQL)

Authenticated `gcloud` required. From the repo root:

```bash
export GCP_PROJECT=your-project-id
export GCP_REGION=us-central1   # optional
chmod +x script/gcp-launch.sh
./script/gcp-launch.sh
```

The script enables APIs, creates a MySQL 9.7 Cloud SQL instance + database user, stores `MYSQL_PASSWORD` / `SECRET_KEY_BASE` in Secret Manager, builds the image with Cloud Build into Artifact Registry, and deploys `bigbuck-api` on Cloud Run with the Cloud SQL socket attached. Health: `GET /v1/health`.

### Web (Vercel)

Remix app in `web/` deploys as a Node `server.ts` on Vercel Fluid Compute. See [`web/README.md`](./web/README.md#deploy-on-vercel).

### Google OAuth (API)

Create an OAuth 2.0 **Web** client in Google Cloud Console (Internal consent screen for demos; External + verification before customer accounts).

Redirect URI:

```text
https://<rails-api-host>/v1/oauth/google/callback
```

API env:

| Variable | Purpose |
|---|---|
| `GOOGLE_CLIENT_ID` | OAuth client id |
| `GOOGLE_CLIENT_SECRET` | OAuth client secret |
| `GOOGLE_REDIRECT_URI` | Exact callback URL above |
| `WEB_ORIGIN` | Remix origin (Vercel URL) for post-login redirect |
| `WEB_ORIGINS` | Allowed browser origins for CORS (include `WEB_ORIGIN`) |
| `BIGBUCK_BOOTSTRAP_TOKEN` | Required header value (`X-Bigbuck-Bootstrap-Token`) for `POST /v1/organizations` in production |
| `BIGBUCK_DEMO_SIGN_IN` | `1` only on demo deployments: enables email sign-in at `POST /v1/sessions` |

Google sign-in redirects back to the web app's `/session?code=…` with a one-time code; the web
server trades it at `POST /v1/sessions/exchange`. No token or user id ever appears in a URL.

Status: `GET /v1/oauth/google/status` · Start: `GET /v1/oauth/google?slug=<org-slug>`
