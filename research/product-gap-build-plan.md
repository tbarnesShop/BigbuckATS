# Product gap build plan

**Status:** P1–P6 landed on `cursor/product-gap-wave-29a9` (after pools merged to `main`).  
**Goal:** Close the gaps between domain services (M0–M9) and recruiter-facing REST + Remix UI, toward the [release gate](./build-plan.md#release-gate).

## Principles

1. REST first, then thin Remix over the same `/v1` surface.
2. Prefer wiring existing services over new domain logic.
3. Fake Gmail/Calendar backends stay for tests; no Google verification in this wave.
4. Hardening, SAML/SCIM, SMB, AI remain **v2 / out of v1**.

## Phases

| Phase | Slice | REST | UI | Proves |
|---|---|---|---|---|
| **P1** | Sequences + enrollments | list/create sequences; enroll person; list enrollments; stop; inbound reply stops | Sequences index; enroll from person/pool member; enrollment status on person | Sourcer enrolls → send → reply stops |
| **P2** | Scorecards | list/create on interview | Application interviews + submit scorecard | HM submits rating before stage move when guarded |
| **P3** | Coordinator scheduling | panel suggest+book on application; list interviewer users lightly | Application “Book panel” form | Panel booked via availability engine |
| **P4** | Platform reads | `GET /v1/events` (or sync people), webhook endpoints index/create, config plan/apply thin | Admin pages: Events, Webhooks, Config plan | Sync/webhook/config callable from UI |
| **P5** | CRM + compliance light | companies index/create; compliance policies list; erasure trigger | Companies list; person erase (admin) | Company linked; erase from UI |
| **P6** | Session | Google sign-in stub session endpoint + Remix env/session | Replace `?org=` with session cookie when present | Demo SSO path without customer Workspace |

## Out of this wave

- Full OpenAPI → openapi-typescript codegen (hand-written `@bigbuck/sdk` methods remain; `invoke` / `bigbuck api` already cover every `operationId`)
- Full candidate portal, e-sign vendors, LinkedIn/job boards
- Load/pen/SOC 2
- Real Google OAuth app verification / CASA

## Execution order

Ship P1→P3 in one PR if cohesive; P4–P6 follow immediately on the same branch if green. Update [`api-ui-parity.md`](./api-ui-parity.md) and [`progress.md`](./progress.md) when each phase lands.
