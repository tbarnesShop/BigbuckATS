# Agent guide (repository root)

BigBuck ATS: a Rails 8.1 API (Ruby 4.0, MySQL 9.7) with a Remix 3 web app in `web/`, plus `sdk/`, `cli/`
and `mcp/` packages. `web/AGENTS.md` covers web conventions, `DESIGN.md` the UI standard, `LOCAL_LAB.md`
running the lab, `SECURITY.md` / `LOCAL_SECURITY.md` the security model. Read the one that matches the change.

## Local environment

- MySQL **9.7** on port **3307**, user/password `bigbuck`/`bigbuck`, for development and tests. Match the
  production version; do not use another server (an older 8.x on 3306 or a 26.x install) for this app.
- Rails: `MYSQL_PORT=3307 MYSQL_USER=bigbuck MYSQL_PASSWORD=bigbuck bin/rails s -p 3000 -b 127.0.0.1`
- Web: `pnpm --dir web run dev` (port 44100). Rails memoizes persisted queries, so restart Rails after
  `persist-queries`.
- Prefix every `bin/rails` command with the same `MYSQL_*` variables.

## Definition of done (run before pushing, not after)

GitHub Actions is turned off, so nothing checks a PR for you. Even when it ran, `.github/workflows/security.yml`
covered only style, security and lint (no tests, no typecheck). Every check happens locally. Run these yourself:

| Changed                                          | Run                                                                                                                                                                                                                            |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Any Ruby                                         | `bin/rubocop` on the changed files, then the related tests (`bin/rails test test/...`)                                                                                                                                         |
| A route, controller action or endpoint           | also `test/ci/openapi_contract_test.rb` (every `/v1` route must be in `openapi/openapi.yaml`) add the action to `app/controllers/concerns/authorization.rb`, run `pnpm --dir mcp run build` to regenerate `mcp/generated/`, and `pnpm --dir sdk run generate` for `sdk/generated/operations.json` (CLI `bigbuck api` / SDK `invoke`) |
| Any web file                                     | `pnpm --dir web run typecheck`, `pnpm --dir web run lint`, `node web/scripts/check-format.mjs`                                                                                                                                 |
| User-visible copy, ordering or a flow            | `grep -rn` the old text in `test/` and `web/app/**/*.test*.ts`, update expectations in the same change                                                                                                                         |
| GraphQL documents (`web/app/data/operations.ts`) | `pnpm --dir web run persist-queries`, then restart Rails (the drift test in `persisted-queries.test.ts` fails otherwise)                                                                                                       |
| Before opening the PR                            | full `bin/rails test` and `pnpm --dir web test`, plus what CI used to run: `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` and `pnpm --dir web lint`                                                          |
| The hiring loop                                  | with servers running: `pnpm --dir web run verify:hire` (prospect → pool → convert → interviews → offer → accept → hired)                                                                                                       |

Run the targeted tests while working; the full Rails suite takes about five minutes.

## Gotchas

- **`db/structure.sql`**: a dump adds GTID and AUTO_INCREMENT noise. Restore the file and hand-apply only the
  real schema change. New columns also go in `config/data_classes.yml`.
- **Scopes**: `app/services/scopes.rb` and `web/app/data/scopes.ts` must stay in step (`scopes.test.ts`).
- **Labels**: never render stored values (`pending_approval`, `hiring_manager`) as text. Use `label()` from
  `web/app/data/labels.ts`; times use `whenLabel()` (America/New_York).
- **Demo sandboxes**: lab writes are limited by `DemoPolicy` / `DemoContext`. Candidate-facing writes (apply,
  accept, decline) depend on `BIGBUCK_DEMO_CANDIDATE_WRITES`, safe only because the deployed web service is
  private (IAM invoker). Never make the Cloud Run services public.
- **`verify:hire` writes records** to the sandbox it signs in to. Run it against local servers, not the shared
  demo someone is auditing.
- **Pipelines** always end in the system Hired stage (`type: "hired"`); hire through `SubjectTransitions.hire`,
  not a stage move.
- zsh: write `${VAR}` before a `:` (`$VAR:r` is a modifier).

- **Vercel (web)**: Vercel bundles only files its tracer sees from imports, and `includeFiles` does not apply
  to this Node-server entrypoint. So browser assets are prebuilt at build time (`web/scripts/prebuild-assets.ts`
  writes `app/assets-manifest.json` + `app/assets-files.json`; `app/assets.ts` serves them) and runtime files
  must be read by a fixed `new URL('./x', import.meta.url)` path. Never commit those generated files: when
  present, local dev serves them instead of compiling. Test a Vercel build locally with `vercel build`.

## Git and deploy

- Branch from `main`, open a PR, squash-merge. Don't delete a branch another open PR targets (it closes that PR).
- Deploy is `script/gcp-launch.sh` and only after merge. Ask before deploying, reseeding or deleting anything
  remote.
- The API deploys with `script/gcp-launch.sh` (Cloud Run). The web app deploys to Vercel (your project
  and team; see `script/vercel-setup.sh`) from the repo root:
  `vercel deploy --prod --scope <team> --yes --archive=tgz`, then
  `vercel alias set <new deployment url> <project>.vercel.app --scope <team>`. That address is an alias, not a
  project domain, on purpose: project domains bypass Vercel Authentication and would make the app public. So
  a production deploy does not move it on its own. Never add a domain to the project.
