# Research

Technical specifications for Big Buck: one enterprise platform for the ATS and talent CRM. **Start with [build-plan.md](./build-plan.md)** and [progress.md](./progress.md).

M0–M10 are built (Rails + MySQL + Remix 3). Remaining sourcer/partner work and hardening are **v2** — see [sourcing-market-gaps.md](./sourcing-market-gaps.md) and [progress.md](./progress.md#v2-paused).

## Living docs (read these)

| File | Contents |
|---|---|
| [build-plan.md](./build-plan.md) | v1 contents, milestones, release gate, launch dependencies, Rails/MySQL mapping |
| [architecture.md](./architecture.md) | Services, shared ATS + CRM table spine, design rules, scale and sizing |
| [decisions.md](./decisions.md) | Founding decisions and signed-off technical defaults |
| [progress.md](./progress.md) | What each milestone built; v2 pause list |
| [v1-scope.md](./v1-scope.md) | Product scope, integration status labels, out of v1 |
| [api-ui-parity.md](./api-ui-parity.md) | REST ↔ Remix coverage; deferred / v2 UI |
| [sourcing-market-gaps.md](./sourcing-market-gaps.md) | 2026 sourcing matrix; M10 shipped; remaining = v2 |
| [api-strategy.md](./api-strategy.md) | REST + GraphQL over one service layer; versioning, sync, webhooks |
| [data-model.md](./data-model.md) | Unified ATS + talent CRM entity model |
| [permissions.md](./permissions.md) | RBAC, field-level visibility, access control |
| [workflow.md](./workflow.md) | Application, offer, and interview state machines |
| [offers.md](./offers.md) · [scheduling.md](./scheduling.md) · [candidate-communications.md](./candidate-communications.md) · [consent-and-compliance.md](./consent-and-compliance.md) | Domain specs |
| [recruiting-as-code.md](./recruiting-as-code.md) · [job-pipelines.md](./job-pipelines.md) · [org-structure.md](./org-structure.md) | Config, pipelines, dimensions |
| [security.md](./security.md) | Threat model; hardening / SOC 2 roadmap (**v2**) |
| [competitors.md](./competitors.md) · [competitor-api-deep-dive.md](./competitor-api-deep-dive.md) | Vendor analysis |
| [owner-setup.md](./owner-setup.md) | SMB preset (**v2**): owner setup checklist |
| [schema-map.md](./schema-map.md) | ERD-style entity relationship map |
| [product-gap-build-plan.md](./product-gap-build-plan.md) · [ui-product-plan.md](./ui-product-plan.md) | Closed waves (historical build notes) |
| [cli-strategy.md](./cli-strategy.md) · [agentic-integrations.md](./agentic-integrations.md) · [migration-sync-engine.md](./migration-sync-engine.md) | CLI / agents / migration designs |
| [landscape.md](./landscape.md) · [license.md](./license.md) · [references.md](./references.md) | Market / OSS / sources |

## Key decisions

- **Direction:** clean-room modern ATS, not a fork of any OSS codebase
- **Stack (current):** Rails API + MySQL (Cloud SQL) + Remix 3 web; Solid Queue; OpenAPI contract; GraphQL for the app/agents alongside REST (decision 13)
- **CLI / MCP / SDK:** thin clients over the same `/v1` API
- **AI:** no AI helpers in v1; when added (v2), helper only — draft, never decide
- **Agents:** controlled MCP tool surface, not raw database access
- **Data model:** one `person` record for ATS and talent CRM; versioned pipeline templates
- **Tenancy:** every tenant table carries `organization_id`; app scopes + composite FKs (MySQL has no RLS)
- **Workflow:** stage moves, rejections and hires are commands; every change is an outbox event
- **Configuration:** versioned config revisions with plan/apply from files or the UI
- **v1:** enterprise ATS + CRM; sales-led onboarding; M0–M10 shipped; SMB preset later
- **v2:** hardening / SAML / SCIM; Chrome extension + enrichment + SMS; LinkedIn RSC / job boards / marketplace; events/newsletters; AI helpers
- **Scheduling:** Google Calendar + Meet in v1; Microsoft 365 WIP
- **Compliance:** company-authored policies; Big Buck records and enforces them
