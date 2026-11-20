# Page chrome migration plan

Prepared November 9, 2026. Design baseline: [`DESIGN.md`](../DESIGN.md). Reference layout: Job workspace (`web/app/actions/jobs/workspace.tsx`) — context chips + underline section tabs + stage-group filter segments.

**Status:** Implemented on `cursor/page-chrome-plan-2cf1`. Shared primitives, page migrations, DESIGN.md, and mobile-row selectors are in. Web suite: 116/116 pass.

**Outcome:** Every working page uses one layered chrome on desktop and mobile. Accent-filled pills stop being local navigation. Search/Create, docs, lab, careers, and board card chrome stay out of scope.

---

## 1. Target pattern

| Layer | Role | Visual | Shared primitive |
| --- | --- | --- | --- |
| Frame | Back/title + global Search/Create | Existing `Shell` header | keep `Shell` |
| Context | Read-only summary + one secondary page action | `chip-row` + ghost button | `PageSubhead` |
| Section nav | Peer views of the same record or hub | Underline `.tabs` | `SectionTabs` |
| View filter | Narrow what the current section shows | Quiet segmented track (today’s `.stage-groups`) | `FilterSegments` |
| Content | Board, table, form, settings body | Page-owned | unchanged |

**Selection rules**

- Tabs change *where you are* (Pipeline vs Settings; Offers Pending vs Accepted).
- Segments change *what you see inside* that place (All / Reviewing; Who / Saved search).
- Chips only *describe* (Active, openings, Engineering). Never selected nav.
- Pagination is neither tabs nor segments: quiet prev/next (or numbered) controls with their own class.
- One primary action per task region; secondary actions stay ghost/text.

**Mobile contract (unchanged intent, clearer owners)**

- Section tabs: one sideways-scrolling row with edge fade; no wrap; ≥44px targets on coarse pointers.
- Filter segments: full-bleed quiet track that scrolls sideways; selected segment raised, not accent-filled.
- Summary chips may wrap.
- No page-private scroll/wrap rules. Fix once in `kit.ts`.
- Person’s documented 2×2 tab grid is **removed** as an exception; person uses the same single-row tabs as Job. Update `DESIGN.md` accordingly.

---

## 2. What we are retiring

| Current pattern | Where | Replacement |
| --- | --- | --- |
| Accent `.pill[aria-current]` as hub/status nav | Offers, Jobs index, Applications index, Interviews Show/Scope, People Who, Admin sections | `SectionTabs` or `FilterSegments` by role |
| `SectionPills` / `foldPills` | Today, Jobs, People/Pools/Companies/Sequences, Applications, Analytics, Proposals, Settings | Rename → `SectionTabs` / `foldLinks` (or keep fold helper name, change renderer) |
| `nav.chip-row` as filters | Tasks, Proposals views, Rediscovery buckets | `FilterSegments` |
| `.pills.list-pagination` | People, Applications | `ListPagination` (new quiet control) |
| Job Settings in-page jump pills | `#job-posting` … `#openings` under Settings tab | Settings side/segment nav **or** remove once settings sections are grouped enough to scan without jumps |
| Page-only `.job-tabs` / `.person-tabs` | Job, Person | Absorbed into shared `SectionTabs` spacing |

Keep `div.chip-row` for non-interactive status/summary only. Keep `.pill` only if a true chip-like **action** remains after migration; selected local nav must not use the filled accent treatment.

---

## 3. Out of scope (do not bundle)

- Global Search/Create behavior or `Shell` frame redesign
- Pipeline board cards, column chrome, move preview UX
- Table density / list-row redesign
- Docs reading layout, lab entry/workspace, careers/public candidate frames
- API, DB, Cloud Run deploys
- New product features (only chrome/role migration)

---

## 4. Inventory (implementation checklist)

### Shared foundation

| ID | Work |
| --- | --- |
| F1 | Add `PageSubhead`, `SectionTabs`, `FilterSegments`, `ListPagination` under `web/app/ui/` |
| F2 | Generalize `.stage-groups` styles to `.filter-segments` (keep alias during migration) |
| F3 | Stop accent-fill on nav pills; either delete selected-pill accent rules for nav or stop using `.pill` for nav |
| F4 | Remove `.job-tabs` / `.person-tabs` once shared spacing exists |
| F5 | Update `DESIGN.md` Page patterns: layered chrome, role rules, kill “build from `.pills`” as the default; note Job as reference; drop person 2×2 exception |
| F6 | Point `mobile-pill-rows` / `entry.ts` row selectors at `.tabs` and `.filter-segments` (and pagination separately) |

### Hub / fold section nav (`SectionPills` → `SectionTabs`)

| Surface | File(s) |
| --- | --- |
| Today fold | `today/page.tsx`, `analytics/pages.tsx`, `proposals/page.tsx` |
| Jobs fold | `jobs/pages.tsx`, `applications/index-page.tsx` |
| People fold | `people/pages.tsx`, `pools/pages.tsx`, `companies/pages.tsx`, sequences list if present |
| Settings fold | `settings-nav.tsx` (+ Shell injection) |
| Helper | `app-nav.tsx` (`SectionPills`, `foldPills`) |

### Hub status / view filters → tabs or segments

| Surface | Current | Decision |
| --- | --- | --- |
| Offers by state | `.pills` | `SectionTabs` (peer hubs) |
| Job status (index) | `.pills` | `SectionTabs` or `FilterSegments` — prefer tabs if URL is the status scope |
| Application status | `.pills` | same as Jobs |
| Interviews Show + Scope | two `.pills` rows | both `FilterSegments` (or Show as tabs if it feels like peer hubs) |
| People Who | `.pills` | `FilterSegments` under People list |
| People saved searches | `.pills` | `FilterSegments` |
| Admin sections | `.pills` | `SectionTabs` |
| Tasks views | `nav.chip-row` | `FilterSegments` |
| Proposal views | `nav.chip-row` | `FilterSegments` |
| Rediscovery buckets | `nav.chip-row` | `FilterSegments` |

### Record workspaces

| Surface | Work |
| --- | --- |
| Job | Already reference; switch stage-groups class to shared `FilterSegments`; resolve Settings jump pills |
| Person | Already `.tabs`; drop 2×2 docs/CSS leftovers; use `SectionTabs` |
| Offer / Sequence show | Align `page-subhead` to `PageSubhead` |
| Application show | Candidate pipeline / Review pill rows → segments or in-page tabs |

### Pagination

| Surface | Work |
| --- | --- |
| People list | Replace `.pills.list-pagination` with `ListPagination` |
| Applications index | same |

---

## 5. Phases

Dependency: **0 → 1 → 2 → 3 → 4 → 5**. One PR per phase unless a phase is trivially small.

### Phase 0 — Standard and inventory lock

**Purpose:** Make the target enforceable before code churn.

- [x] **P0.1** Update `DESIGN.md` with the layered chrome table, selection rules, mobile contract, and explicit retirement of accent-pill local nav. Record person 2×2 removal.
- [x] **P0.2** Freeze the inventory above against `web/app` (grep for `.pills`, `nav.chip-row`, `SectionPills`, `list-pagination`, `stage-groups`). Add any missed consumer to §4.
- [x] **P0.3** Decide Job Settings jump pills: keep as `FilterSegments` / mini tabs, or delete after settings grouping check.
- [x] **P0.4** Before screenshots deferred; post-migration coverage via web e2e (Job, Offers, People, Interviews, Person, mobile filter rows).

**Exit:** DESIGN.md matches the target; inventory complete; settings decision recorded; before images stored under ignored `tmp/` or `research/design-cleanup-review/page-chrome/before/`.

### Phase 1 — Shared primitives

**Files:** `web/app/ui/` (`page-chrome.tsx` or split files), `kit.ts`, thin re-exports from `app-nav.tsx` if needed.

- [x] **P1.1** Implement `PageSubhead`, `SectionTabs`, `FilterSegments`, `ListPagination` with accessible names, `aria-current`, counts via shared `tab-count`, empty via `data-empty`.
- [x] **P1.2** CSS: shared tab spacing; `.filter-segments` (= today’s stage-groups look); pagination styles; ensure mobile scroll/fade lives only here.
- [x] **P1.3** Migrate Job workspace to the new primitives without visual regressions (reference pilot).
- [x] **P1.4** Temporary compatibility: `SectionPills` can wrap `SectionTabs` **or** be deleted in Phase 2 in the same week — do not leave two public APIs long-term.

**Exit:** Job still matches the approved reference; unit/e2e smoke for job tabs + stage filter pass; no new page-private chrome CSS.

### Phase 2 — Kill accent-pill section nav

- [x] **P2.1** Replace `SectionPills` / Settings / all fold consumers with `SectionTabs`.
- [x] **P2.2** Rename helpers (`foldPills` → something accurate) and update imports.
- [x] **P2.3** Offers, Jobs index, Applications index, Admin → tabs (or segments per §4).
- [x] **P2.4** Remove accent selected styles from any remaining nav `.pill` usage, or delete dead pill-nav CSS.

**Exit:** Grep shows no fold/`SectionPills` accent nav; hubs use tabs; desktop + mobile screenshots for Offers/Jobs/People fold.

### Phase 3 — Filters, pagination, record leftovers

- [x] **P3.1** Interviews, People Who, saved searches, Tasks, Proposals, Rediscovery → `FilterSegments`.
- [x] **P3.2** `ListPagination` on People and Applications.
- [x] **P3.3** Application show pipeline/review rows; Offer/Sequence `PageSubhead`.
- [x] **P3.4** Execute Job Settings decision from P0.3.

**Exit:** No `nav.chip-row` filters; no `.pills.list-pagination`; application/record chrome aligned.

### Phase 4 — Person mobile + CSS cleanup

- [x] **P4.1** Person on shared `SectionTabs` only; remove any 2×2 rules/docs.
- [x] **P4.2** Delete `.job-tabs`, `.person-tabs`, unused `.section-pills` margins, and `.stage-groups` alias if fully renamed.
- [x] **P4.3** Confirm summary `div.chip-row` still wraps and is excluded from filter-row tests.

**Exit:** One tab language everywhere; kit.css has one owner per chrome role.

### Phase 5 — Verification and standard lock

- [x] **P5.1** Update `mobile-pill-rows` (rename if helpful), `entry.ts` scroll helpers, and any e2e that click `.pill` for nav.
- [x] **P5.2** Full matrix: every working page at 1440×900 and 390×844, light/dark — tabs/segments single-row verdict.
- [x] **P5.3** `pnpm --dir web` typecheck, lint, format check, web tests; targeted Playwright for Offers/People/Job/Person/Interviews.
- [x] **P5.4** Final DESIGN.md pass: no leftover “build rows from `.pills`” as the global default; Job remains the cited reference.

**Exit:** Checks green; review screenshots attached to the closing PR; plan marked complete.

---

## 6. Execution rules

- Branch from current `main`; one coherent PR per phase.
- Prefer rewriting call sites to shared components over restyling `.pill` globally.
- Do not add tests that only assert CSS values; extend behavior/mobile-row tests where nav role changes.
- Preserve URLs, permissions, and count semantics; only change presentation/role.
- Counts use the same scope as linked destinations (existing DESIGN.md rule).
- If a surface needs an exception, record it in DESIGN.md with benefit and verification — do not invent a third mobile pattern.

---

## 7. Suggested first implementation slice

After plan approval, ship **Phase 0 + Phase 1** together if small, otherwise Phase 0 then Phase 1:

1. DESIGN.md + inventory lock  
2. Shared primitives  
3. Job migrated as the living reference  

Then Phase 2 immediately so accent pills do not remain the default beside the new system.

---

## 8. Success criteria

A recruiter can move Job → Offers → People → Interviews → Settings and see the same chrome grammar: context (when needed), underline sections, quiet filters, content. Mobile filter/tab rows never wrap into multiple lines. Grep for selected accent nav pills on working pages returns nothing. Person no longer documents a separate 2×2 tab layout.
