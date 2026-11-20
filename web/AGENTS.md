# Web Agent Guide

This app was scaffolded with `remix new`. Use these conventions when continuing to build it out.

## Design standard

Read [`../DESIGN.md`](../DESIGN.md) before creating or changing UI. It is the current baseline for branding, shared visual roles, page organization, accessibility, and scrolling behavior across docs, lab, and recruiter pages. Use semantic tokens and the existing Shell, Field, buttons, records, disclosures and named overflow regions. Run `pnpm run design:check` for obsolete font/palette aliases. Implement shared patterns through tokens and components and verify the affected layouts and interactions.

## Commands

```sh
pnpm install
pnpm run dev
pnpm run hmr
pnpm run start
pnpm test
pnpm run typecheck
pnpm run design:check
```

Use `pnpm run hmr` for live server and browser updates; `pnpm run dev` only watches and restarts the server. `pnpm run start` runs in production mode without a separate build step.

## Building Features

Refer to ./.agents/skills/remix/SKILL.md for the Remix mental model and how to find guides and API READMEs through `node_modules/remix/INDEX.md`.

## Starter Layout

- `app/routes.ts` defines the shared route contract used by server and browser modules for type-safe hrefs
- `app/router.ts` wires routes to controllers and installs the standard Remix component renderer used by actions
- Put top-level route actions in `app/actions/controller.tsx`; add `app/actions/<route-key>/controller.tsx` for nested route maps. `app/actions/controller.test.ts` is the root controller's router smoke test
- `app/actions/home-page.tsx` and `app/actions/document.tsx` render the route-owned starter UI
- `app/actions/public/` contains the browser runtime entry and interactive prompt button
- `app/assets.ts` owns the server-side asset pipeline used by the asset route and render middleware
- Root `public/` contains static files served unchanged from the app root

This starter intentionally begins small; add directories like `app/data/`, `app/middleware/`, `app/ui/`, and `test/` only when you need them.
