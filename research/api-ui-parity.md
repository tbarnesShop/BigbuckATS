# API ↔ UI parity

**Status:** Product gap wave merged; MCP tools in `mcp/` (plan: [`product-gap-build-plan.md`](./product-gap-build-plan.md)).

Goal: every recruiter-facing `/v1` capability has a matching Remix surface, and new ATS actions land in REST first.

## Covered

| API | UI |
|---|---|
| People CRUD + timeline + send + erase | People list/create/show + timeline Frame + email + erase |
| Affiliations create/list | Person “Link company” |
| Jobs CRUD + pipeline stages | Jobs list/create + pipeline board |
| Applications + transitions | Application dossier, move/reject |
| Projects / members + convert | Pools index/board + member convert; person pools |
| Sequences + enrollments + stop; mailbox inbound | Sequences index/enroll; person enrollments list |
| Scorecards create | Application interview scorecard form |
| Application bookings (panel suggest+book) | Application “Book panel” form |
| Offers create/submit/approve/send/rescind + public accept/decline | Offer detail actions + candidate letter |
| Scheduling links + public show/book + interviews | App scheduling section + public `/scheduling/:token` |
| Careers public + org branding PATCH | Careers hero + `/settings/careers` admin |
| Companies index/create | Admin companies |
| Config plan/apply + plans list | Admin “Config as code” |
| Compliance policies index | Admin compliance list |
| Events + sync/people; webhooks index/create | Admin events + webhooks |
| Sessions (verified-domain demo) | `/session` demo SSO → home with `?org=&actor=` |

## Platform

| Item | Status |
|---|---|
| OpenAPI → MCP tools (`mcp/`) | Built — `operationId` tools, writes gated by `BIGBUCK_MCP_ALLOW_WRITES` |
| OpenAPI → TypeScript SDK + CLI | Built — `@bigbuck/sdk` + `@bigbuck/cli` ergonomic ops; `client.invoke` / `bigbuck api` cover every OpenAPI `operationId` (same catalog as MCP REST tools) |
| CSV people import REST | Built — `POST /v1/imports` |

## M10 sourcing ops

| API | UI |
|---|---|
| People search filters + bulk | People index search + bulk enroll/DNC |
| Saved searches | Built: save, reopen and delete on People; smart pools refresh from one; enroll a search from a sequence |
| Sequences shared/template + bulk enroll + task steps | Sequences create ships email/wait/task |
| Job rediscovery | Job show “Rediscovery” |
| Analytics funnel/sourcing | `/analytics` |
| DNC companies | API (+ enrollment blocked); Admin → Do not contact |
| Referrals | `/referrals` |
| Requisitions open/close + job.requisition_id | `/requisitions` |

## Still deferred / v2

| Item | Notes |
|---|---|
| Full OpenAPI codegen (openapi-typescript) | Hand-written thin SDK + generated operations catalog for now; typed codegen later |
| Hardening / SAML / SCIM / SMB | v2 |
| Cookie-backed session (no query params) | Demo still redirects with `?org=` |
| Chrome extension / enrichment / SMS / LinkedIn RSC | **v2** (former sourcing P1/P2) |
