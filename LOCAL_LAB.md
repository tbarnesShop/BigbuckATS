# Interactive lab and developer docs

The lab is a working proof of concept, with real Rails operations and no model/API billing dependency. The public entry is `/session`; anonymous `/` redirects there. Documentation starts at `/docs`. Ordinary sign-in is `/session/login`; OAuth still returns to `/session`.

## Run locally

Use MySQL 9.7 (on port 3307 locally; set `MYSQL_PORT=3307` for every `bin/rails` command), Ruby/Bundler, Node 24, and pnpm. Create the database user using your local MySQL setup, then from the repository root:

```sh
bundle install
MYSQL_PORT=3307 MYSQL_USER=bigbuck MYSQL_PASSWORD=bigbuck bin/rails db:prepare demo:prepare
pnpm --dir sdk install
pnpm --dir sdk run build
pnpm --dir cli install
pnpm --dir cli run build
pnpm --dir mcp install
pnpm --dir mcp run build
pnpm --dir web install
```

Start Rails and Remix in separate terminals:

```sh
MYSQL_PORT=3307 MYSQL_USER=bigbuck MYSQL_PASSWORD=bigbuck \
  WEB_ORIGINS=http://127.0.0.1:44100,http://localhost:44100 \
  bin/rails server -b 127.0.0.1 -p 3000
```

```sh
pnpm --dir web run hmr
```

Open `http://127.0.0.1:44100/session`. The default API address is `http://127.0.0.1:3000`; set `RAILS_API_URL` for a different backend. Production needs `SESSION_SECRET` and `BIGBUCK_DEMO_SIGN_IN=1` explicitly. Demo sign-in defaults on in development.

The MCP and CLI explorers require their built artifacts, a Node server capable of starting child processes, access to the committed contracts, and a writable `tmp/lab-cli` directory. An Edge-only host does not satisfy these requirements. Rebuild SDK/CLI/MCP after changing their sources.

API and agent bearer credentials stay in private, expiry-bound files in `tmp/lab-sessions`; the browser session contains an opaque reference. Set `LAB_CREDENTIAL_DIR` to relocate this storage. Multiple web hosts require shared storage. Expired files are removed on lookup and issuance; the UI retains its existing HTTP-only session behavior.

## Sandbox lifecycle

`demo:prepare` creates two registered organizations using `BigBuckDataset`: UI, and a shared tools tenant (`big-buck-lab-tools`) behind MCP, API, and CLI. These are separate from the original `big-buck` fixture tenant and the automated test database. Explore and Compare select the interface's tenant; Connect selects the CLI tenant throughout.

`bin/jobs` runs the existing Solid Queue scheduler. `ResetDemoSandboxesJob` checks overdue workspaces every minute, resetting each one on its interval (hourly by default, daily in development; `BIGBUCK_DEMO_INTERVAL_HOURS` overrides, and the hosted demo sets a longer one). Requests also check deadlines when the scheduler is unavailable. Database named locks serialize resets and requests; lock queries explicitly bypass Rails' query cache. A busy/resetting workspace returns a recoverable error. Generations invalidate old contexts; reset removes old credentials. Visitors cannot request a public reset.

All workspaces are shared. Person, pool, application, and job links resolve against the current generation. Outbound Gmail/calendar operations and webhook delivery are captured locally. Registered demo tenants add destructive-operation and identity restrictions to normal authorization, including indirect erasure through compliance requests. These restrictions apply to direct REST and GraphQL requests too.

CLI files are created in a token-specific temporary directory. The runner starts the actual CLI with parsed arguments, without a shell, and constrains file arguments to bundled CSV/configuration paths. Temporary files are disposable; remove old `tmp/lab-cli` directories as part of host maintenance. Production rate limits, quotas, exhaustive abuse testing, and deployment hardening remain follow-up work.

## Demo seed data

`BigBuckDataset` is the small deterministic fixture (100 people, 2 jobs) that tests and the e2e fixtures rely on. `BigBuckDemoSeed` extends it with demo-quality content: 13 jobs and 15 requisitions, 7 pipeline templates (one versioned, one job with per-job overrides), about 170 more candidates with real PDF resumes, applications in every stage with coherent interview loops, scorecards and offers in every status, upcoming interviews, message/offer/question templates, sequences with enrollments and replies, sourcing pools, referrals, saved searches, agents, webhooks, an import run, and compliance records. It lives in `lib/big_buck_demo_seed.rb` and `lib/big_buck_demo/`.

- Lab sandboxes use it by default in development, so the UI, MCP, API and CLI tenants all show the rich dataset after each reset. Tests and production keep the small dataset. Set `BIGBUCK_DEMO_ENRICH=1` or `0` to override either way. A sandbox reset takes about 35 seconds with enrichment (about 15 without).
- `bin/rails db:seed` builds or tops up the `big-buck` org, and is safe to re-run. `RESET=1` wipes and rebuilds that org; `FORCE=1` re-runs the enrichment on an existing one. Demo sign-in is limited to the registered lab tenants, so use `/session` to browse the data in the UI.
- To see the new data in an already-running dev lab right away: `bin/rails runner 'DemoSandbox::SURFACES.each { |s| DemoWorkspaces.prepare!(s, force: true) }'`.

## Author docs and stories

Concept prose lives in `web/docs/*.md`. `web/app/data/docs.ts` builds local search and renders articles. REST references read `openapi/openapi.yaml`; MCP references read the generated catalog and curated tool definitions; GraphQL reads `schema.graphql`; CLI reads command help. Explanations remain separate from contract facts.

`web/app/data/lab/stories.ts` resolves seed references and completion from real records. Successful read observations and configuration/import IDs are associated with the signed session. Deep links prepare an interface/operation/step and never submit a domain write.

## Verify

```sh
pnpm --dir web run typecheck
pnpm --dir web run test
MYSQL_PORT=3307 MYSQL_USER=bigbuck MYSQL_PASSWORD=bigbuck bin/rails test \
  test/controllers/v1/demo_lab_test.rb \
  test/controllers/v1/identity_test.rb \
  test/services/config_plan_apply_test.rb \
  test/ci/openapi_contract_test.rb
```

With Rails and Remix running, the live check exercises disposable demo records, real MCP stdio, actual CLI files/config/imports, docs links, copying, and desktop/mobile layouts:

```sh
pnpm --dir web exec playwright install chromium
pnpm --dir web run verify:lab
```

Screenshots go to ignored `tmp/lab-verification/`. V2 conversational execution is planned; V1 discovers and executes tools without a language model.

Verified locally: security/reset/API regression checks (41 tests), the web suite, additional server credential/restart checks, TypeScript strict checking, and the live four-interface workflow. Remix doctor passes environment/project checks and reports action-directory naming warnings for grouped controllers; these route maps are exercised by the web tests. The local scheduler is not running; request-based overdue recovery and reset coordination were tested.
