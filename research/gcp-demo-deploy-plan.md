# GCP demo deployment plan

Prepared November 6, 2026. **Status: deployed November 7, 2026, private.** Both Cloud Run services require IAM (only the operator's account has `run.invoker`); the API uses `ingress=internal` and the web service reaches it over Direct VPC egress; Cloud SQL was upgraded in place to MySQL 9.7 (8.0 → 8.4 → 9.7, after recreating the DB users off `mysql_native_password`). Every command is in `script/gcp-launch.sh`, which prints instead of executing unless `APPLY=1` is set.

Decisions already made: **demo** environment (`BIGBUCK_DEMO_SIGN_IN=1`, seeded lab sandboxes, no Google OAuth), **scale to zero** (no always-on worker), reuse an existing stopped Cloud SQL instance, your own project, region `us-central1`.

## 1. Remix on Cloud Run instead of Vercel

**Recommendation: run the Remix app on Cloud Run too.** Both services in one project, one script, no Vercel account.

### Does the Remix server run in a container?

Yes, and it needs no adapter. `web/server.ts` is a plain `node:http` server wrapping `router.fetch` with `createRequestListener` from `remix/node-fetch-server`. There is no React Router or framework adapter, and no Vercel preset in the code. Vercel-specific parts are only `web/vercel.json` and the `vercel.nft` block in `web/package.json`, which a container ignores. It runs TypeScript directly (`node --import remix/node-tsx server.ts`), so **there is no web build step**. Node 24 is required (`engines`).

### What the container needs that Vercel does not give you

The web app reads files **outside `web/`** at runtime (`repoRoot = process.cwd()/..` in `web/app/data/lab/catalog.ts`): `openapi/openapi.yaml`, `schema.graphql`, `mcp/generated/tools.json`, `cli/src/cli.ts`, and it spawns `mcp/dist/server.js` and the CLI as child processes. `sdk/dist`, `cli/dist` and `mcp/dist` are gitignored build output, built by three separate pnpm projects (cli depends on `file:../sdk`).

So yes, **the web app needs the SDK, CLI and MCP packages built first**, and the whole repo layout present at runtime. `Dockerfile.web` does this: build sdk, then cli, then mcp (whose build regenerates `mcp/generated/tools.json`), then install web with `--prod`, and run with the working directory at `/app/web`.

### Is Vercel worse for this app?

For this app, yes, and the problem predates the cloud move:

- `web/vercel.json` sets no build command and the project root is `web/`. The files above would not be deployed unless "include source files outside the root directory" is enabled, and the `dist/` directories would not exist. The `/docs` reference pages and the lab explorers would break unless extra build wiring is added.
- The lab explorers need child processes and a writable filesystem (`tmp/lab-cli`, `tmp/lab-sessions`). `LOCAL_LAB.md` states they need a Node server that can start child processes and shared credential storage across hosts. Vercel Fluid Compute can run many ephemeral instances, so credential files written on one are missing on another.
- On Cloud Run with `max-instances=1`, the app has one long-lived filesystem, so credentials persist across requests while the instance lives.

Caveat: **a cold start or restart loses lab credentials**, because they are files on that instance's disk. The browser then gets bounced to `/session` to pick a persona again. Acceptable for a demo; `min-instances=1` on the web service (about $10-13 a month, estimate) avoids it.

### Cold start

Measured locally (this laptop, warm disk cache): server up and answering `/docs` in **0.6 s**, 214 MB resident. On Cloud Run expect roughly 2-4 s for a cold web container with startup CPU boost (estimate, not measured on Cloud Run). The Rails API is the heavier cold start, with eager loading in production, likely 5-10 s (estimate). A visit after idle pays both in sequence. Mitigation: open the site once a few minutes before a demo.

### Cost, estimated

Cloud Run web at demo traffic sits inside the free tier (about $0). Vercel Hobby is $0 but non-commercial; Pro is about $20 a month per seat. Cloud Run is the same or cheaper.

### Origin and auth

- Both services are on `*.run.app` but are still two origins.
- **CORS is not actually needed for this app.** The browser only talks to the Remix origin (the one browser-side fetch, in `web/app/ui/public/resume-viewer.tsx`, is same-origin). Remix talks to Rails server to server with `Authorization: Bearer`, held in the signed `__bigbuck` cookie. `WEB_ORIGINS` is still set (as the README says), but nothing depends on it.
- Same project means one set of secrets and IAM, and the predictable Cloud Run URL (`https://<service>-<project-number>.us-central1.run.app`) lets the script configure each service with the other's address before either exists.
- The API stays publicly invokable (Cloud Run `--allow-unauthenticated`), because Remix does not present Google credentials. Rails authenticates every request itself.

### Region

Vercel's configured region is `iad1` (Virginia) and the database is in us-central1, which would have added a cross-region hop on every request. Putting both services in us-central1 removes that.

## 2. Architecture

| Piece | Choice |
|---|---|
| Database | Existing Cloud SQL `bigbuck-mysql` (MySQL 8, db-f1-micro, 10 GB SSD). Start it, enable `log_bin_trust_function_creators` (required by the audit triggers in `db/structure.sql`; currently missing), enable daily backups, require SSL. |
| API | Cloud Run `bigbuck-api`, 1 vCPU / 1 GiB, min 0 / max 2, startup CPU boost, Cloud SQL unix socket |
| Web | Cloud Run `bigbuck-web`, 1 vCPU / 1 GiB, min 0 / **max 1** (lab credentials live on local disk) |
| Migrations | Cloud Run Job `bigbuck-migrate` (`db:prepare`). The image entrypoint's boot-time `db:prepare` is skipped with `BIGBUCK_SKIP_DB_PREPARE=1`, so cold instances don't race on the schema or pay for it at boot. |
| Seeding | Cloud Run Job `bigbuck-seed` (`demo:prepare`) with `BIGBUCK_DEMO_ENRICH=1`, creating the two `big-buck-lab-*` sandboxes (`ui`, and `tools` shared by MCP, API and CLI) from the enriched seed (PR #72) |
| Documents | New private GCS bucket for resumes (`BIGBUCK_DOCUMENT_BUCKET`) |
| Identity | Dedicated runtime service account with only Cloud SQL client, access to the four secrets, and object admin on the one bucket (the old script used the default compute account) |
| Images | Artifact Registry `bigbuck`; Cloud Build builds both images from one config |

### Env vars and secrets

API and jobs: `RAILS_ENV`, `MYSQL_DATABASE`, `MYSQL_USER`, `CLOUD_SQL_CONNECTION_NAME`, `GOOGLE_CLOUD_PROJECT`, `BIGBUCK_DOCUMENT_BUCKET`, `BIGBUCK_ALLOWED_HOSTS` (the API host; **production.rb raises without it**, and the old script never set it), `WEB_ORIGINS`, `WEB_ORIGIN`, `BIGBUCK_DEMO_SIGN_IN=1`, `BIGBUCK_DEMO_ENRICH=1`, `SOLID_QUEUE_IN_PUMA=true`, `BIGBUCK_SKIP_DB_PREPARE=1`. Secrets from Secret Manager: `MYSQL_PASSWORD` and `SECRET_KEY_BASE` (exist), `BIGBUCK_BOOTSTRAP_TOKEN` (new).
Web: `RAILS_API_URL`, and `SESSION_SECRET` (new secret; the app refuses to start in production without 32+ characters).

## 3. What visibly will not work at scale-to-zero

Cloud Run only gives an instance CPU while it is serving a request. The Solid Queue scheduler runs inside the API process (`SOLID_QUEUE_IN_PUMA`), so recurring jobs (`config/recurring.yml`) run only in short bursts while someone is actively using the demo, and not at all when idle. **Do not demo these paths and expect them to work on their own:**

| Feature | Job | What you will see |
|---|---|---|
| Sequences advancing | `AdvanceSequencesJob` (every 5 min) | Seeded enrollments never send their next step by themselves. Enroll someone live and nothing follows. |
| Outbox relay and webhook deliveries | `RelayOutboxJob` (10 s), `DeliverWebhooksJob` (30 s) | Events don't fan out; the webhook delivery lists stay empty or stale. |
| Offer expiry | `ExpireOffersJob` (15 min) | Offers past their expiry stay "sent". |
| Scorecard nudges | `ScorecardNudgeJob` (hourly) | No reminders are generated. |
| Retention, idempotency purge, contact cleanup | nightly/weekly | Invisible for a demo. |

**The hourly sandbox reset still works, lazily.** `DemoWorkspaces` also checks deadlines on requests (`with_demo_context`). The first request after the hour triggers the reset inline (about 35 s with the enriched seed on a fast database; likely slower on db-f1-micro, unmeasured) and returns "The demo has refreshed. Choose a persona to start again." Expect one slow request and one prompt to re-pick a persona. The web client allows 120 s and Cloud Run 300 s.

**Escape hatch before a demo:** a Cloud Run Job can run those jobs once on demand (for example `bin/rails runner 'RelayOutboxJob.perform_now; AdvanceSequencesJob.perform_now; ExpireOffersJob.perform_now'`). Not in the script yet; add if you want it.

## 4. Cost, estimated (verify in the pricing calculator)

| Item | Monthly |
|---|---|
| Cloud SQL db-f1-micro running, 10 GB SSD, backups | about $10-13 |
| Cloud SQL stopped (disk only) | about $2 |
| Cloud Run API + web, demo traffic, scale-to-zero | about $0-3 |
| Secret Manager, Artifact Registry, GCS, Cloud Build | under $2 |
| **Total while running** | **about $12-18** |
| Optional: API `min-instances=1` (no API cold start) | about +$13 |
| Optional: web `min-instances=1` (keeps lab sessions) | about +$13 |

Vercel is not used, so no Vercel cost. Recommend a $25 billing budget alert (not in the script; needs the Billing API and an owner decision).

## 5. Risks and unknowns

- `Dockerfile.web` is **untested**. Docker isn't running on this machine, so nothing was built. The first Cloud Build is the first real test of it.
- A db-f1-micro (shared core, about 0.6 GB RAM) may make the seed and the sandbox reset much slower than the ~35 s measured locally. The seed job has a 30-minute timeout.
- No cache database is configured for Solid Cache in production; whether it works against the primary database is unverified until first boot.
- Document scanning: the image installs ClamAV but I don't know how the scanner behaves without signature files.
- The old script gave the Cloud Build/compute accounts broad project roles. The new script grants none; Cloud Build worked on Oct 31 (two images exist), so the grants likely persist. If the build fails on permissions, the error names the missing role.
- Because the demo uses one DB account, MySQL grants don't protect `audit_events` from the app (see `AuditPurge`). Fine for a demo; not for production.
- The image is built from the working tree. Commit first and build from a clean tree. `Gemfile.lock` and `mcp/generated/tools.json` have uncommitted edits that predate this work.
- Seed data is in PR #72, which is not merged. `BIGBUCK_DEMO_ENRICH=1` does nothing until it is.

## 6. Step list for approval

Nothing below has been run. Each step is one phase of `script/gcp-launch.sh`; `APPLY=1 ./script/gcp-launch.sh <phase>`.

0. **Prerequisites (no cost):** merge PR #72, commit these deployment files, build from a clean tree.
1. **`infra`** (starts billing): enable APIs; patch Cloud SQL (start, set flag, backups, SSL; one restart); create the database; create or reset the `bigbuck` SQL user from the existing password secret; create `bigbuck-bootstrap-token` and `bigbuck-session-secret`; create the private bucket; create the runtime service account and bind its roles.
2. **`build`**: Cloud Build both images and push to Artifact Registry.
3. **`migrate`**: deploy and run the `bigbuck-migrate` job and wait.
4. **`deploy`**: deploy `bigbuck-api` then `bigbuck-web`, and verify the real URLs match the predicted ones.
5. **`seed`**: deploy and run `bigbuck-seed` and wait (minutes).
6. **`smoke`**: health checks and the sign-in page.
7. **`stop`** when finished: stops Cloud SQL (about $2 a month while stopped).

Rollback: `gcloud run services delete` for each service, `gcloud sql instances patch --activation-policy=NEVER`. Deleting the Cloud SQL instance or the bucket is deliberately not scripted.
