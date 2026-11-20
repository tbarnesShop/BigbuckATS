# Sourcing & ATS Market Gap Research

**Date:** 2026-11-04 (updated after M10)  
**Status:** Research complete; **M10 shipped** (P0 + referrals + openings). Remaining sourcer/partner gaps are **v2**.  
**Related:** [`competitors.md`](./competitors.md), [`competitor-api-deep-dive.md`](./competitor-api-deep-dive.md), [`v1-scope.md`](./v1-scope.md), [`progress.md`](./progress.md), [`api-ui-parity.md`](./api-ui-parity.md)

## Goal

Map what sourcing-focused recruiting tools and modern ATS+CRM platforms ship in 2026, then score Big Buck’s **actually built** product against that market. Produce a prioritized gap backlog for product decisions.

## Positioning default

Compete as an **Ashby / Gem All-in-One–style ATS + talent CRM**, not as a SeekOut / hireEZ talent-graph point solution.

Big Buck already chose one person record, one schema, one API, and no CRM↔ATS sync tax ([`v1-scope.md`](./v1-scope.md)). Recommendations prioritize CRM-in-ATS depth over owning an external 1B-profile search database.

## Market segments

| Segment | Players | What they sell |
|---|---|---|
| Network search | LinkedIn Recruiter | Profile DB + InMail + filters; limited multi-channel CRM |
| AI talent graph | SeekOut, hireEZ, Juicebox, ContactOut | External search across the open web, enrichment credits, export / ATS sync |
| Recruiting CRM | Gem (CRM-first), Ashby Sourcing & CRM | Sequences, pools, rediscovery, sourcing analytics; often on top of an ATS |
| Modern ATS + CRM | Ashby All-in-One, Gem All-in-One, Lever | One product: hire + nurture + report |
| Structured ATS | Greenhouse | Strong hiring workflow + marketplace; CRM / Sourcing Automation as tiered add-ons |
| Enterprise suite / talent CRM | Workday, iCIMS, Beamery, Phenom, Eightfold | Breadth, skills graphs, heavy implementation |

```text
Discovery (LI / SeekOut / hireEZ)
        │  Chrome ext / export / RSC
        ▼
CRM + outreach (Gem / Ashby sourcing)
        │  native or bidirectional sync
        ▼
ATS spine (Greenhouse / Lever / Ashby / Big Buck)
```

Big Buck’s thesis is to collapse the middle and bottom into one product, and **partner or defer** the discovery graph.

## What sourcing tools are doing (2026 pattern)

Primary sources: [Ashby Sourcing & CRM](https://www.ashbyhq.com/platform/recruiting/sourcing-crm), [Ashby pricing feature list](https://www.ashbyhq.com/pricing), [Gem AI sourcing](https://www.gem.com/product/ai-sourcing), [Gem CRM](https://www.gem.com/product/crm), SeekOut / hireEZ / LinkedIn Recruiter positioning pages, [Greenhouse CRM](https://support.greenhouse.io/hc/en-us/articles/360022793612-CRM-overview) and [Sourcing Automation](https://support.greenhouse.io/hc/en-us/articles/5131929423643-Sourcing-Automation-overview). Vendor claims about database size and AI quality are directional.

1. **External talent search** — Boolean + AI natural-language search over vendor-claimed 800M–1B+ profiles.
2. **Chrome extension** — capture LinkedIn (and sometimes Indeed / GitHub / AngelList) into the CRM without leaving the browser.
3. **Enrichment** — email / phone lookup as metered credits.
4. **Multi-channel sequences** — email + LinkedIn InMail / connect + SMS; stop-on-reply; frequency caps; do-not-contact lists.
5. **Talent pools + rediscovery** — silver medalists and past applicants resurfaced per open role (increasingly AI-ranked).
6. **Bulk enroll / send-on-behalf / shared templates**.
7. **Sourcing analytics** — response rate, source-of-hire, pipeline contribution, DEI filters.
8. **Referrals + events + newsletters** — attraction beyond 1:1 sequences.
9. **ATS sync or all-in-one** — Gem still sells “CRM on your ATS”; Ashby / Gem All-in-One sell consolidation; Greenhouse sells CRM + Sourcing Automation as product tiers / seats.

Ashby’s published sourcing checklist is the best mid-market feature list to score against: sequences, Chrome extension, projects, Boolean + AI search, email lookups, enrichment, confidential projects, AI rediscovery, outreach frequency policy, newsletters, referrals, SMS, openings / headcount, native analytics.

## Big Buck build reality (2026-11)

Source of truth: Rails + Remix code, [`progress.md`](./progress.md), [`api-ui-parity.md`](./api-ui-parity.md), OpenAPI.

**Strong today**

- People spine + lifecycle (`prospect` → `alumni`)
- Projects / pools → convert to application with attribution
- Email sequences + stop-on-reply rails
- Unified person timeline
- Job pipelines, stages, scorecards
- Interviews + scheduling (Google path)
- Offers + approvals + click-to-accept
- Custom fields, careers page, config-as-code
- REST / GraphQL / MCP / SDK / CLI

**Shipped in M10**

People search + saved filters + bulk actions; sequence templates / bulk enroll / task steps; job rediscovery; funnel + sourcing analytics; outreach cooldown + company DNC; referrals with attribution; requisitions / openings (plus `jobs.openings` from product-parity).

**Still partial / thin (v1 keep or v2)**

| Area | Reality |
|---|---|
| Sequences | `email` + `wait` + `task` run; SMS / InMail remain v2 |
| Mail sync | Inbound stop-on-reply path exists; real Gmail verification is a launch gate |
| Companies | Affiliations exist; no account-based sourcing campaigns (v2) |
| Candidate experience | Secure single-purpose links; full portal out of v1 |
| DNC / saved searches UI | APIs shipped; admin / saved-search UI polish is thin |

## Capability matrix

Legend: **Y** = first-class / native · **P** = partial, add-on, or thinner than leaders · **N** = missing or not a product focus · **—** = not the product’s job

Statuses for Big Buck are code-backed. Competitor cells are from public product / support docs and are directional (not a paid bake-off).

### Sourcing / CRM

| Capability | Big Buck | Ashby | Gem | SeekOut | hireEZ | LinkedIn Recruiter | Greenhouse |
|---|---|---|---|---|---|---|---|
| People / prospects | Y | Y | Y | P | P | P | Y |
| Talent pools / projects | Y | Y | Y | P | P | P | Y |
| Email sequences | P | Y | Y | P | Y | N | Y |
| Multi-channel (InMail / SMS) | N (v2) | Y | Y | P | Y | P | P |
| Stop-on-reply | P | Y | Y | P | Y | — | Y |
| Chrome extension | N (v2) | Y | Y | Y | Y | — | Y |
| External profile search DB | N | N | Y | Y | Y | Y | N |
| Email / phone enrichment | N (v2) | Y | Y | Y | Y | — | Y |
| Boolean / advanced CRM search | P | Y | Y | Y | Y | Y | Y |
| AI search / matching | N (v2) | Y | Y | Y | Y | P | P |
| Rediscovery / silver medalists | Y | Y | Y | P | Y | — | P |
| Referrals program | Y | Y | P | — | — | — | Y |
| Newsletters / events | N (v2) | Y | P | — | — | — | P |
| Sourcing analytics | Y | Y | Y | Y | Y | P | Y |
| Outreach frequency / DNC | Y | Y | Y | P | P | — | P |
| Unified activity timeline | Y | Y | Y | P | P | — | Y |
| ATS sync required | N | N | P | Y | Y | Y | N |

### ATS / hiring

| Capability | Big Buck | Ashby | Gem | SeekOut | hireEZ | LinkedIn Recruiter | Greenhouse |
|---|---|---|---|---|---|---|---|
| Jobs + pipelines + scorecards | Y | Y | Y | — | P | — | Y |
| Scheduling | Y | Y | Y | — | P | — | Y |
| Offers + approvals | Y | Y | Y | — | — | — | Y |
| Careers / job board hosting | Y | Y | Y | — | — | — | Y |
| Job board distribution | N | Y | Y | — | — | Y | Y |
| Native recruiting analytics | Y | Y | Y | P | P | P | Y |
| Requisitions / openings / headcount | Y | Y | P | — | — | — | Y |
| Agency collaboration | N (v2) | Y | P | — | — | — | Y |
| Assessments / bg-check marketplace | N (v2) | Y | P | — | — | — | Y |
| EEO / DEI reporting | N (v2) | Y | Y | Y | P | — | Y |
| SAML / SCIM | N (v2) | Y | Y | Y | Y | Y | Y |
| API / webhooks / developer surface | Y | Y | Y | P | P | P | Y |

## Gap map

### Keep / polish

People CRM spine, pools → application, email sequence rails, timeline, structured hiring, scheduling, offers, custom fields, careers, agent-ready API.

### Competitive gaps — sourcing

- LinkedIn RSC / Chrome extension
- External profile search and enrichment
- SMS / InMail sequence channels
- Referrals with attribution
- Sourcer task steps / task queue
- Sourcing and funnel analytics dashboards
- Outreach frequency policy and company DNC lists
- Newsletters and recruiting events

### Competitive gaps — ATS buyers expect

- Native analytics (time-to-fill, stage conversion, source effectiveness) — a top reason teams cite for switching to Ashby
- Job board distribution (Indeed / LinkedIn / Google Jobs)
- Agency collaboration scopes
- Auto-reject / bulk application review
- EEO / DEI reporting
- Assessment and background-check marketplace
- Internal mobility board
- SAML / SCIM (already planned v2)

## Prioritized backlog

### Shipped (M10) — former P0 + referrals + openings

| Gap | Status |
|---|---|
| People search + saved filters + bulk actions | Shipped |
| Sequence polish: shared templates, bulk enroll, task steps | Shipped (`email` / `wait` / `task`) |
| Rediscovery of past applicants for a job | Shipped |
| Sourcing + funnel analytics | Shipped |
| Outreach frequency / DNC basics | Shipped |
| Referrals with attribution | Shipped |
| Openings / headcount (requisitions) | Shipped |

### v2 — sourcer daily driver (former P1 remainder)

Paused with v1. Closes “I still need Gem + LinkedIn” without building a talent graph.

| Gap | Why later |
|---|---|
| Chrome extension (LinkedIn capture) | Daily sourcer workflow; Greenhouse, Ashby, Gem, hireEZ all ship one |
| Email enrichment partner | Metered lookups, not a Big Buck-owned data graph |
| SMS channel | Multi-channel is table stakes in Ashby / Gem messaging |

### v2 — expand or partner (former P2)

Aligns with Planned / WIP labels in [`v1-scope.md`](./v1-scope.md). AI stays helper-only per product decisions.

| Gap | Approach |
|---|---|
| LinkedIn RSC | Partner-gated; Planned |
| Job board distribution | Partner / Planned |
| Assessment / bg-check marketplace | Provider contract already designed |
| Events / newsletters | After sequences and analytics mature |
| AI search / personalization / rediscovery ranking | Helper drafts and ranking over *our* data; not an interviewer |

### Do not chase

| Item | Why not |
|---|---|
| Own 1B-profile search database | SeekOut / hireEZ core; conflicts with ATS-first focus |
| Full HRIS suite | Workday / SAP trap; hire packet API is enough |
| AI interviewer | Explicitly out of v1; provider rails only |

## Takeaways

1. **The market split is discovery vs relationship vs hiring.** Big Buck should own relationship + hiring; buy or partner discovery.
2. **Ashby is the closest competitive mirror.** Native sourcing CRM + analytics + structured hiring in one product is the bar buyers use.
3. **Gem proves CRM-first still wins deals** when the ATS is weak on outbound — but Gem’s dual CRM/ATS APIs are the architecture Big Buck deliberately avoided.
4. **Greenhouse shows even the structured-hiring leader had to bolt on CRM + Sourcing Automation seats.** Native CRM is a differentiator, not a nice-to-have.
5. **M10 closed the largest sellable CRM-ops gaps** (search/bulk, sequence depth, rediscovery, analytics, DNC, referrals, openings).
6. **Chrome extension + enrichment partner** remains the highest-leverage **v2** path into sourcer daily workflow without a talent graph.

## Bottom line

Big Buck has the **unified spine** competitors assemble from two or three products, and M10 added the core **sourcer workstation** inside the ATS (search, bulk, rediscovery, analytics, outbound hygiene). Remaining gaps are discovery partnerships and multi-channel capture (**v2**), not a SeekOut rebuild.

## Sources

- Ashby: [Sourcing & CRM](https://www.ashbyhq.com/platform/recruiting/sourcing-crm), [Pricing features](https://www.ashbyhq.com/pricing), [AI Talent Rediscovery](https://www.ashbyhq.com/product-updates/ai-talent-rediscovery)
- Gem: [AI sourcing](https://www.gem.com/product/ai-sourcing), [CRM](https://www.gem.com/product/crm), [candidate sourcing tools roundup](https://www.gem.com/blog/candidate-sourcing-software)
- Greenhouse: [CRM overview](https://support.greenhouse.io/hc/en-us/articles/360022793612-CRM-overview), [Sourcing Automation](https://support.greenhouse.io/hc/en-us/articles/5131929423643-Sourcing-Automation-overview), [Chrome extension](https://support.greenhouse.io/hc/en-us/articles/8302875133083-Greenhouse-Recruiting-Chrome-extension-for-Sourcing-Automation)
- Market comparisons (directional): [Articuler sourcing tools](https://www.articuler.ai/resources/compare/candidate-sourcing-tools/), [LinkedIn vs SeekOut vs hireEZ](https://formanorden.com/blog/linkedin-recruiter-vs-seekout-vs-hireez/), [SitePoint sourcing tools](https://www.sitepoint.com/best-sourcing-tools-for-recruiters/)
- In-repo: [`competitors.md`](./competitors.md), [`competitor-api-deep-dive.md`](./competitor-api-deep-dive.md), [`v1-scope.md`](./v1-scope.md), [`progress.md`](./progress.md), [`api-ui-parity.md`](./api-ui-parity.md)
