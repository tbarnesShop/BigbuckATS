<p align="center">
  <img src="design/assets/bigbuck-mark.png" alt="BigBuck" width="96">
</p>

# BigBuck ATS

**An open-source applicant tracking system and talent CRM, built API-first so humans, scripts and AI agents all work the same pipeline.**

One product, one schema: a Rails API on MySQL, a Remix web app on top of it, and first-class MCP, CLI and SDK clients generated from the same OpenAPI contract.

---

## Why use BigBuck

**You own your recruiting data.** Self-host it on your own cloud, your own database, under the MIT license. No per-seat pricing, no export tickets, no vendor lock-in.

**ATS and CRM in one schema.** Candidates, prospects, talent pools, jobs, pipelines, sequences, scorecards, offers and careers pages share one data model. A sourced lead becomes an applicant without a sync job between two products.

**Agent-ready from day one.** Every action in the UI is available over REST, GraphQL, an MCP server, a CLI and a TypeScript SDK. Agents get their own scoped credentials and act *on behalf of* a real user, and every write is audited with who, which agent, which credential and which surface.

**Recruiting as code.** Custom fields and pipeline templates can be defined as config, planned (with impact previews) and applied, so hiring process changes are reviewable like any other change.

**Built for compliance, not bolted on.**
- Append-only audit log enforced by MySQL triggers, with PII hashed per organization
- Consent records, data-subject access packets, erasure (with residual checks) and legal holds
- Per-column data classification (`pii`, `sensitive`, `secret`, `internal`) — a new column fails tests until it is classified
- Retention policies applied automatically by a daily job

**Safe to customize.** Custom fields are versioned and never hard-deleted; type changes are previewed migrations. The GraphQL schema can only change additively — CI blocks breaking changes.

**Real permissions.** Role-based access, confidential jobs, field-level visibility, and tenant isolation checked by `bin/rails tenant:check`.

### Feature highlights

| Area | What you get |
|---|---|
| Recruiting | Jobs, multi-stage pipelines, applications, interviews and scorecards, offers with expiry, hiring teams |
| Sourcing / CRM | People records, talent pools, rediscovery of past candidates, outreach sequences with wait steps, unsubscribe |
| Careers | Public and internal (employee-only) careers sites per organization, per-job publishing |
| Data | CSV import (async for large files), contact-point normalization (E.164 phones), duplicate merge suggestions |
| Integrations | Signed webhooks with retries and SSRF protection, outbox-based event relay, Google sign-in, external OAuth/OIDC for API clients |
| Interfaces | Web app, REST `/v1`, GraphQL (persisted queries), MCP server, CLI, TypeScript SDK |
| Lab | An interactive `/session` sandbox that shows the same system through UI, MCP, API and CLI side by side |

---

## Architecture

```
            ┌──────────────┐   ┌───────────┐   ┌──────────┐   ┌──────────┐
            │  Remix web   │   │ MCP server│   │   CLI    │   │   SDK    │
            │  (web/)      │   │  (mcp/)   │   │  (cli/)  │   │  (sdk/)  │
            └──────┬───────┘   └─────┬─────┘   └────┬─────┘   └────┬─────┘
          GraphQL  │      REST /v1   │              │              │
                   ▼                 ▼              ▼              ▼
            ┌─────────────────────────────────────────────────────────────┐
            │          Rails API  (API-only, OpenAPI + GraphQL)            │
            │   ChangeWriter → audit_events · outbox → webhooks            │
            └───────────────┬──────────────────────────┬──────────────────┘
                            ▼                          ▼
                 ┌────────────────────┐     ┌────────────────────────┐
                 │  MySQL 8.4 / 9.7   │     │  Solid Queue (bin/jobs) │
                 │  data + job queue  │     │  same MySQL database    │
                 └────────────────────┘     └────────────────────────┘
```

| Layer | Tech |
|---|---|
| API | Ruby on Rails (API-only), `db/structure.sql` |
| Database | MySQL 8.4 or 9.7 (Cloud SQL in the reference deploy) |
| Background jobs | Solid Queue on the same MySQL — no Redis required |
| Web | Remix 3 on Node 24, talks to the API over GraphQL + REST |
| Contracts | `openapi/openapi.yaml` (REST) and `schema.graphql`, both enforced by tests |
| Agents / tooling | MCP server, CLI and SDK generated from OpenAPI (pnpm 10) |
| File storage | Local disk in development; private GCS bucket in production |

---

## Infrastructure

BigBuck runs anywhere you can run a Rails container, a Node server and MySQL. The repo ships three deploy paths; pick one.

### 1. Google Cloud (reference deploy)

Rails API and (optionally) the web app on **Cloud Run**, data on **Cloud SQL for MySQL**, secrets in **Secret Manager**, images built by **Cloud Build** into **Artifact Registry**, candidate documents in a private **GCS** bucket.

```bash
gcloud auth login
export GCP_PROJECT=<your-gcp-project-id>
export GCP_REGION=us-central1          # optional

./script/gcp-launch.sh plan            # dry run: prints every command, changes nothing
APPLY=1 ./script/gcp-launch.sh infra   # APIs, Cloud SQL, secrets, bucket, service account
APPLY=1 ./script/gcp-launch.sh build   # Cloud Build → Artifact Registry
APPLY=1 ./script/gcp-launch.sh migrate
APPLY=1 ./script/gcp-launch.sh deploy
APPLY=1 ./script/gcp-launch.sh smoke
./script/gcp-launch.sh stop            # stop Cloud SQL to cut cost when idle
```

The script is **safe by default**: nothing changes until you set `APPLY=1`. It generates `MYSQL_PASSWORD` and `SECRET_KEY_BASE` straight into Secret Manager (values are never printed), runs as a dedicated least-privilege service account, and by default keeps the API on `ingress=internal` so only the web service can reach it. Services scale to zero. See [`research/gcp-demo-deploy-plan.md`](./research/gcp-demo-deploy-plan.md) for the trade-offs.

### 2. Web app on Vercel (API on Cloud Run)

`web/` deploys as a Node `server.ts` on Vercel Fluid Compute (`web/vercel.json`). When the web app lives on Vercel the API must be public, so every request carries a shared edge secret header.

```bash
vercel login
export VERCEL_SCOPE=<your-team> VERCEL_PROJECT=<your-project>
export API_URL=https://<your-cloud-run-api-url>
./script/vercel-setup.sh               # edge secret, Vercel env, keeps the app behind Vercel auth
```

See [`web/README.md`](./web/README.md).

### 3. Any VM with Kamal / Docker

A standard Rails `Dockerfile` (API) and `Dockerfile.web` (Remix) are included, plus a Kamal `config/deploy.yml` template. Point it at your servers and registry, set the env vars below, and deploy.

### Configuration

All configuration is environment variables — nothing secret lives in the repo. Copy `.env.example` (API) and `web/.env.example` (web) to start.

| Variable | Where | Purpose |
|---|---|---|
| `MYSQL_HOST` / `MYSQL_USER` / `MYSQL_PASSWORD` / `MYSQL_DATABASE` | API | Database connection |
| `CLOUD_SQL_CONNECTION_NAME` | API | Use the Cloud SQL unix socket instead of host/port |
| `MYSQL_SSL_CA` | API | Required in production for verified TLS to MySQL |
| `SECRET_KEY_BASE` | API | Rails secret (from your secret manager) |
| `BIGBUCK_ALLOWED_HOSTS` | API | Required in production; host allow-list |
| `WEB_ORIGIN` / `WEB_ORIGINS` | API | Web app origin(s) for CORS and redirects |
| `GOOGLE_CLOUD_PROJECT` / `BIGBUCK_DOCUMENT_BUCKET` | API | Private document storage |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` / `GOOGLE_REDIRECT_URI` | API | Google sign-in (optional) |
| `BIGBUCK_OAUTH_ISSUER` / `_AUDIENCE` / `_JWKS_URI` | API | External OAuth provider for API/CLI clients — see [`OAUTH.md`](./OAUTH.md) |
| `BIGBUCK_BOOTSTRAP_TOKEN` | API | Guards organization creation in production |
| `BIGBUCK_DEMO_SIGN_IN` | API | `1` only on demo deployments (passwordless email sign-in) |
| `RAILS_API_URL` / `SESSION_SECRET` | Web | API base URL and session cookie secret |

Production hardening checklist: [`SECURITY.md`](./SECURITY.md).

---

## Quick start (local)

Requirements: Ruby (see `.ruby-version`), MySQL 8.4+, Node 24, pnpm 10.

```bash
# MySQL with user bigbuck / bigbuck and databases bigbuck_development / bigbuck_test
bundle install
bin/rails db:prepare
bin/rails db:seed            # Big Buck demo dataset: 100 people, staff, pools, hiring teams
bin/rails server             # API on :3000

cd web && pnpm install && pnpm run dev
# open the web app and sign in at /session (demo email sign-in is on in development)
```

Run the tests: `bin/rails test` and `cd web && pnpm test` (includes Playwright e2e).

Full local lab workflow: [`LOCAL_LAB.md`](./LOCAL_LAB.md).

---

## Documentation

| Doc | What's in it |
|---|---|
| [`REFERENCE.md`](./REFERENCE.md) | Developer reference: credentials, GraphQL, compliance APIs, custom fields, background jobs, contracts, audit |
| [`DESIGN.md`](./DESIGN.md) | UI design standard |
| [`OAUTH.md`](./OAUTH.md) | API/CLI authentication with an external OAuth/OIDC provider |
| [`SECURITY.md`](./SECURITY.md) | Security model and production hardening |
| [`POSTING_FORMS.md`](./POSTING_FORMS.md) | Job posting application forms |
| [`mcp/`](./mcp/README.md) · [`cli/`](./cli/README.md) · [`sdk/`](./sdk/README.md) | Agent and developer tooling |
| [`research/`](./research/) | Architecture, data model, API strategy and design decisions |

## Contributing

Issues and pull requests are welcome. Branch from `main`, keep `bin/rails test`, RuboCop, Brakeman and the web lint/tests green — CI runs them along with dependency audits on every PR.

Please report security issues privately (GitHub **Security → Report a vulnerability**) rather than in a public issue.

## License

[MIT](./LICENSE)
