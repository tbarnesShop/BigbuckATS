# Web

A minimal Remix application starter with a home page.

## Starter Shape

- `app/actions/controller.tsx` owns the top-level route actions.
- `app/actions/home-page.tsx` and `app/actions/document.tsx` render the route-owned starter UI.
- `app/actions/public/` contains the browser runtime entry and interactive prompt button.
- `app/routes.ts` defines the shared route contract used by server and browser modules for type-safe hrefs.
- `app/router.ts` wires routes to handlers and installs the standard Remix component renderer used by actions.
- `app/assets.ts` owns the server-side asset pipeline used by the asset route and render middleware.
- Root `public/` contains static files served unchanged from the app root.

## Growing The App

- Put top-level route actions in `app/actions/controller.tsx`.
- Add `app/actions/<route-key>/controller.tsx` when a nested route map needs its own actions or middleware.
- Add directories like `app/data/` or `test/` when the app actually needs them.
- Move shared UI into `app/ui/` once more than one route needs it.

## GraphQL

Pages that need nested data (Today, the job workspace, person custom fields, settings) call Rails
`POST /graphql` server-side with the signed-in user's token. Every document lives in
`app/graphql/operations.ts`.

```sh
pnpm run codegen          # app/graphql/generated.ts from ../schema.graphql
pnpm run persist-queries  # registers documents in ../app/graphql/persisted_queries.json
```

Browser sessions may only run registered documents, so run both after changing an operation; CI
fails if either output is stale.

## Theme

Light and dark themes come from CSS custom properties in `app/ui/tokens.ts`. Dark follows the
device setting; the Auto / Light / Dark toggle in the header stores a choice in the session. Use
the `color.*` tokens in components, never raw colours.

## Commands

```sh
pnpm install
pnpm run dev
pnpm run hmr
pnpm run start
pnpm test
pnpm run typecheck
```

## Deploy on Vercel

This Remix 3 app is a Node `server.ts` entrypoint (Fluid Compute). From `web/`:

```sh
pnpm dlx vercel login
pnpm dlx vercel link          # set Root Directory to web/ if linking from the repo root
pnpm dlx vercel env add RAILS_API_URL
pnpm dlx vercel --prod
```

Required env on the Vercel project:

| Variable | Purpose |
|---|---|
| `RAILS_API_URL` | Public Rails API origin (no trailing slash) |

| `SESSION_SECRET` | Signs the `__bigbuck` session cookie (required in production) |

Optional: `BIGBUCK_ORG_SLUG` (default careers slug), `BIGBUCK_TOKEN` (local tooling only).

Sign-in stores the Rails session token in a signed, HTTP-only cookie. Pages call Rails with
`Authorization: Bearer`; identity never travels in URLs.

On the Rails API, set `WEB_ORIGINS` to the Vercel URL(s) (comma-separated) and `WEB_ORIGIN` to the primary app URL used after Google OAuth.

## UI design

Read [DESIGN.md](../DESIGN.md) before changing a surface. Use semantic roles from `app/ui/tokens.ts`; the document owns font loading. Reuse `Shell`, `Field`, `PrimaryButton`, `EmptyState`, `RowList` and the shared kit rather than defining another control system. Use record sections for related information, named keyboard-focusable regions for wide tables/boards, and native disclosures for optional setup. Settings navigation is shared through `SettingsNavigation`.

Preserve organization branding on careers and candidate pages. Keep pending, failed and permission-unavailable states distinct. Verify the affected workflow, both themes, narrow reflow and mobile input text before merging. Run `pnpm run design:check` to detect obsolete palette/font aliases; legitimate geometry, artwork and organization imagery are intentionally outside that check.
