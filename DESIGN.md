# BigBuck design standard

Established November 5, 2026. This is the design baseline for new UI work and the target for bringing existing pages into alignment. It defines intended behavior; it does not claim the current implementation already meets these rules.

This file owns enduring visual roles, shared component behavior, layout patterns, and verification expectations for agents creating or changing UI. Migration plans own phase order, temporary compatibility rules, implementation inventories, and task-specific acceptance fixtures. Product specifications own queue eligibility, ownership, and other domain decisions. Update this standard when an improvement should apply broadly.

## Direction and references

BigBuck should feel like a clean, professional workspace: compact, readable, predictable, and calm. People should quickly understand what they are looking at, what needs attention, and what to do next.

Use these references deliberately:

| Reference | Preserve | Apply to |
| --- | --- | --- |
| [BigBuck v1](https://bigbuck.tbarnesbuilds.fyi/) | Original buck mark, BigBuck wordmark treatment, homepage visual identity | Branding and public entry |
| v1 recruiter Today | Actions requiring attention first; upcoming interviews, offers, and pipeline context second | Recruiter home and work queues |
| Current developer docs at `/docs` | Navigation sidebar, central reading area, supporting outline, clear topic organization | Documentation and workspace organization |
| Current lab | Working UI, MCP, API, and CLI experiments | Functionality, rebuilt within a compact workspace |

The [v1 repository](https://github.com/tbarnesShop/BigBuck-ATS) is a reference for assets and behavior. Implement these rules within the current Rails/Remix application rather than copying its code.

This standard supersedes the visual direction in `research/ui-product-plan.md` and the older Ledger & Canopy mockups. Those documents remain historical references. Product requirements and technical architecture continue to apply.

## Core principles

1. **Organization before decoration.** Prioritize the user's task, then arrange supporting context around it. A page should have a clear reading order and a clear primary action.
2. **Density through structure.** Use aligned rows, tables, concise labels, and grouped metadata. Do not achieve density by shrinking essential text or touch targets.
3. **Space communicates relationships.** Related items sit close together. Sections have a larger separation. Empty space must help orientation or readability.
4. **Consistency includes behavior.** Tabs, selection, navigation, execution, loading, and scrolling behave predictably across surfaces.
5. **Color has a purpose.** Use it for identity, selection, focus, and status. Avoid decorative color categories and unrelated accents.
6. **Keep people oriented.** Maintain visible task context and preserve their position when content updates.

## Brand

Use **BigBuck** in product branding, page titles, and new product copy. Preserve existing API identifiers, organization names, and routes where changing them would affect behavior.

The original logo is stored at [`design/assets/bigbuck-mark.png`](./design/assets/bigbuck-mark.png). It was retrieved from `https://bigbuck.tbarnesbuilds.fyi/mark.png` on November 5, 2026. Preserve its proportions and original artwork; do not substitute the current `b.` tile, a generic deer icon, or an AI-generated replacement.

- Use a 24–28px mark in working navigation, paired with the BigBuck wordmark.
- Keep at least 8px between mark and wordmark and enough surrounding space to distinguish it from controls.
- Preserve the homepage's prominent buck, restrained background glow, and simple composition. Rebuild the treatment responsively in this application.
- Keep the expressive homepage treatment on the public entry. Working pages use the compact layout rules below.
- Verify the supplied raster asset at its intended sizes in both themes. If a different variant is needed, obtain an original source asset rather than distorting or recoloring this one ad hoc.

## Typography

Use one sans-serif family across navigation, headings, controls, and prose. **IBM Plex Sans**, already used by the application, is the initial family. Use a system monospace stack for code, commands, and identifiers. Remove serif styling from working page headings and navigation.

| Role | Size | Weight | Line height |
| --- | --- | --- | --- |
| Page title | 24px | 600 | 1.25 |
| Section title | 16px | 600 | 1.35 |
| Body, navigation, form controls, table content | 14px | 400; 500–600 for emphasis | 1.45 |
| Secondary metadata and supporting labels | 13px | 400–500 | 1.4 |
| Compact badges and tertiary metadata | 12px | 400–600 | 1.4 |
| Documentation prose | 15px | 400 | 1.65 |
| Code and response content | 13px | 400 | 1.5 |
| Public homepage heading | 32–40px, responsive | 600 | 1.2 |

Use semantic roles instead of choosing a new size per page. Documentation shares the page and section heading sizes while retaining comfortable prose spacing. Ordinary mobile text keeps the same readable sizes. Editable inputs, selects, and textareas on narrow or touch-oriented layouts use at least 16px text, including code editors, to avoid common iOS Safari focus zoom. Static code and responses may retain their code role; do not disable browser zoom.

Use sentence case for headings and labels. Reserve uppercase for short established labels such as HTTP methods. Keep readable labels out of monospace. Use weight, alignment, and proximity to distinguish information before introducing another size. Essential information must not rely on 9–11px text or faint contrast.

## Color and surfaces

Use a neutral light/dark system with one restrained violet accent, drawing from v1's identity. The values below are the initial implementation baseline, not sampled claims about v1. Validate contrast and appearance when implementing shared tokens.

| Semantic token | Light | Dark | Purpose |
| --- | --- | --- | --- |
| `background` | `#F7F8FA` | `#101217` | Page canvas |
| `surface` | `#FFFFFF` | `#191C24` | Panels, menus, controls |
| `surface-subtle` | `#EEF0F4` | `#222631` | Table headers and quiet grouping |
| `text` | `#20242C` | `#F1F2F5` | Primary content |
| `text-muted` | `#596170` | `#ABB2C0` | Supporting content |
| `border` | `#D7DBE3` | `#373D4B` | Structural dividers |
| `control-border` | `#808896` | `#788298` | Boundaries needed to identify controls |
| `accent` | `#6246D9` | `#A594FF` | Primary actions, links, selection |
| `accent-hover` | `#5135BD` | `#B8ABFF` | Hover on primary actions |
| `accent-pressed` | `#422A9F` | `#C6BCFF` | Pressed primary actions |
| `on-accent` | `#FFFFFF` | `#151120` | Content on accent fills |
| `accent-subtle` | `#EEE9FF` | `#2D2645` | Selected backgrounds |
| `success` | `#176B45` | `#78D6A5` | Successful completion |
| `warning` | `#855700` | `#EAC16B` | Attention required |
| `danger` | `#B42332` | `#FF9AA6` | Errors and destructive actions |

Expose these through the shared theme tokens. Components use semantic names; no page owns a separate palette. The quiet `border` token is for structural dividers. Use `control-border` when the boundary identifies a control, checking at least 3:1 contrast against its actual surface.

Use an accent focus outline, initially 2px wide with a 2px surface-colored offset. Ensure it remains visible against filled controls and is not clipped by overflow. Selected items use `accent-subtle`, primary text, an accent indicator, and the appropriate selected/current semantics. Secondary hover uses `surface-subtle`; primary hover and pressed fills retain `on-accent` text. Define readable disabled treatments and expose disabled semantics rather than dimming the entire component indiscriminately.

Use explicit shared status foreground/background pairs. Pair color with a label or icon; verify rendered contrast rather than deriving a different tint on each page.

| Status | Light foreground / background | Dark foreground / background |
| --- | --- | --- |
| Success | `#176B45` / `#E8F4ED` | `#78D6A5` / `#17372B` |
| Warning | `#855700` / `#FFF3D6` | `#EAC16B` / `#3B301B` |
| Danger | `#B42332` / `#FDECEF` | `#FF9AA6` / `#40232C` |

Support system, light, and dark theme choices consistently. Keep surfaces visually distinct in both themes. Use borders as the default separator; reserve shadows for overlays and raised menus. Background glow belongs to the public homepage. Avoid glass panels, gradients, and shadows throughout ordinary work areas.

## Spacing and geometry

Use the spacing scale **4, 8, 12, 16, 24, 32px**. Default page padding is 24px on desktop and 16px on narrow screens. Default panel padding and grid gaps are 16px; use 24px between major sections.

| Element | Default |
| --- | --- |
| Standard button or input | 36px minimum height |
| Compact table row | 40–44px minimum height; expand for multiline content |
| List row with supporting detail | 48px minimum height; expand as needed |
| Control radius | 6px |
| Panel radius | 8px |
| Badge radius | 4px |
| Border | 1px |
| Desktop navigation rail | 224–240px |

On touch-oriented layouts, provide at least 44px interaction targets or equivalent target spacing. Keep text selectable and support browser zoom. Content drives height; never clip meaningful text to satisfy a density target.

Avoid a separate card around every item. Use plain section headings, dividers, and rows for related content. Cards are for distinct tasks or independent groups. Keep data and actions aligned across repeated rows.

## Page patterns

Working pages share one layered chrome. Reference: Job workspace. Migration notes: [`research/page-chrome-migration.md`](./research/page-chrome-migration.md). Shared primitives live in `web/app/ui/page-chrome.tsx`.

| Layer | Role | Primitive |
| --- | --- | --- |
| Frame | Back/title + Search/Create | `Shell` |
| Context | Read-only summary + one secondary page action | `PageSubhead` (`chip-row`) |
| Section nav | Peer views of the same record or hub | `SectionTabs` / `FoldSectionTabs` |
| View filter | Narrow what the current section shows | `FilterSegments` |
| Content | Board, table, form | page-owned |

Tabs change *where you are*. Segments change *what you see*. Chips only *describe*. Pagination uses `ListPagination`, not tabs or segments. Do not use accent-filled pills for local navigation. Progress through stages uses a quiet `.step-track`, not selectable nav.

### Shared working frame

All working surfaces share the same brand, navigation vocabulary, theme control, heading scale, and component styling. Docs, lab, and recruiter pages may have different navigation contents and column arrangements to serve their tasks.

Use one compact theme button on desktop and mobile. Show the current Auto, Light or Dark setting; each press advances Auto → Light → Dark → Auto. Its accessible name and tooltip identify the current setting and next choice. Keep the session preference and native form submission behavior.

Demo recruiter pages and the active lab share a slim, full-width sticky banner above navigation and content. It names the demo workspace and current persona, offers Change persona and Back to lab, and shows the reset countdown. From the recruiting app, Back to lab returns to the public four-interface entry. Technical workspaces retain their interface and mode on that return link. On narrow screens keep the demo identity and return action visible; move reset and sandbox details into a disclosure. Let long names wrap, keep sticky navigation below the banner's measured height, and announce expiration once rather than every countdown update. Ordinary demo sign-in uses the same banner with sample-data context; public candidate pages retain their own task frame.

Keep Search and Create in one aligned action row. On narrow screens place that row below the page title, keep the Create label visible, and use a clearly named search-icon submit button with a 44px touch target. Hide desktop keyboard hints there and anchor dropdowns within the available row width.

Place the title, short supporting context, and primary action in a compact page header. Put section tabs and view filters immediately beneath it. Give the working content the remaining space. On narrow screens, tab and filter rows stay in one sideways-scrolling row (tabs) or a full-bleed segmented track (filters); they do not wrap into multiple rows that push working content below the fold. Build rows from the shared `.tabs` and `.filter-segments` styles; pages add no per-page scrolling or wrapping rules. Summary chips may wrap. Use one primary action per task region; other actions use secondary or text treatments.

Use persistent navigation on desktop and a compact, accessible navigation control on narrow screens. Avoid simultaneous sidebars and repeated navigation menus for the same destinations. Collapse optional columns according to available content width, including under zoom, before squeezing the primary reading or editing region. Modal navigation provides an accessible name, deliberate initial focus, Escape/close behavior, focus containment, and focus return. Respond to available main content width when moving header actions below the title, including beside a desktop rail. Use the browser modal top layer for mobile navigation so background controls cannot overlap it; close it when persistent desktop navigation becomes visible. Keep destination suggestions and Create disclosures as ordinary links unless the complete keyboard behavior of a menu or listbox is implemented. Escape and focus departure dismiss transient controls; preserve typed input and return focus without scrolling. Provide usable navigation before browser enhancement loads.

The shared foundation lives in `ui/tokens.ts`, with `bb-base`, `bb-kit`, `bb-surfaces`, then Remix component layers. Lab and docs styles are scoped to their page roots. The document owns the IBM Plex Sans request for working and bare layouts. All consumers use semantic roles; historical palette/font aliases have been removed. `web/scripts/check-design.mjs` detects their reintroduction. The migration history is in `research/design-cleanup-foundation.md`. The original dark mark uses a light backing in both themes rather than recoloring its artwork. Text over careers imagery uses the explicit white image-text role independently of theme.

### Developer docs: preserve the layout

Keep the existing left navigation, central article, and optional right outline. Preserve topic grouping, search, breadcrumbs, code examples, and previous/next navigation.

- Bound long-form prose to roughly 65–80 characters per line. Wide reference tables may use more space.
- Normalize fonts, headings, controls, and colors through shared roles without replacing the reading layout.
- Keep the outline visible when space allows; collapse it before squeezing the article.
- On narrow screens, put topic navigation behind an explicit control rather than a wall of links above the article. Keep search reachable, let the topic disclosure overlay the article without moving it, and support Escape and outside dismissal. Code and table overflow regions need accessible names and keyboard access; copy feedback announces success or failure without moving focus or changing the example.
- Anchor links may scroll to their named section. Offset anchors for sticky headers and preserve browser history behavior.

### Lab: make the workspace the destination

Separate public introduction from active experimentation. The public lab entry briefly explains the four interfaces and offers clear choices, while retaining BigBuck’s personality: an original buck aligned to the full headline/supporting-copy height on desktop, a two-line headline with violet emphasis, inviting card headings and small illustrative interface previews. Keep public entry focused on the four interface choices; omit the Explore/Compare/Connect mode picker from both entry and active lab screens. Existing mode deep links continue to work. UI persona selection offers one representative each for Owner, Admin, Recruiter and Hiring Manager. Use the public heading role and keep all four desktop choices and their actions comfortably visible. Keep previews subordinate to the choices and distinguish illustration from live results. Avoid oversized previews, repeated pitches, and fixed-height empty blocks. Once an interface is selected, remove the public composition so the next task stays direct.

Once an interface is selected, open a workspace with a compact title and MCP/API/CLI interface controls immediately to its right. Hold the authenticated persona when switching technical interfaces; enter the matching persona in the destination sandbox without reopening selection. Keep draft recovery and expiry checks in place. After expiry, exact input remains available for copying and the leave guard; history navigation cannot replace it, and old completion/record evidence must be cleared. UI persona selection opens Today directly, with no separate UI workbench. UI step deep links open the corresponding recruiting page within the current sandbox. Do not retain the full introductory hero and interface cards above the active experiment.

Temporary rate limits or service failures keep the selected persona and offer an explicit retry to the same workspace context. Do not label them as expired sessions or force persona selection. Retry reopens the workspace without executing a request; genuine authentication or expiry failures still require re-entry.

On desktop, organize the workspace around:

| Region | Content |
| --- | --- |
| Left | Experiment or operation navigation, current selection, concise instructions |
| Center | Editable inputs, execution action, response and errors |
| Right, when useful | Related record or supporting context |

The center receives the most width. Hide or collapse optional record detail before narrowing the editor excessively. On narrow screens, show selection controls followed by the active editor, action, response, and optional record details. Do not put a long experiment catalog above the active task. Keep the selected request or tool visible in a disclosure summary, with search and selection inside. Place Suggested experiments and supporting links in a separate disclosure. Open these navigation regions on desktop and collapse them on narrow screens. Keep the step choices concise; put the experiment introduction, detailed step explanations and help links in a separate About this experiment disclosure. The common sidebar should fit a 1280×720 window without scrolling past explanatory copy. Longer flows and deliberately expanded guidance may extend the document. Keep the underlying contents available before enhancement loads.

Keep request and result adjacent. For a long editor, offer clearly labeled Request/Response views or an explicit View response action. Keep execution status visible near Run so completion is apparent without forcing a page jump. Response-anchor navigation and its Back/Forward entries preserve the existing completion status. Disable duplicate execution without removing focus from the initiating action; restore editor focus only if rendering lost it and the user has not moved elsewhere.

Collapse lengthy schemas, permissions, and raw record details behind descriptive controls. Keep the information needed to execute the current task visible. Preserve unfinished raw input, including malformed JSON, independently of validation. Retain drafts and selected context across compatible changes; if a transition would discard work, explain it and provide a recovery path before discarding. Restore context only within its authorized identity and valid workspace generation. The workflow specification defines recovery boundaries; do not infer compatibility from matching labels.

### Recruiter Today: personal work first

Use a compact Today heading with the current date. In the primary column, show the signed-in person's remaining interviews today, followed by their pending feedback with direct actions. Keep application review counts, offers awaiting approval, pipeline volume, later personal interviews, and existing agent context in the supporting column. Do not repeat today's interviews in the later schedule.

Collapse to one column when the available content width becomes narrow, keeping interviews and feedback first. Use compact rows with readable metadata and touch-sized actions. Counts and destination labels must state the returned scope and qualify capped slices. Show useful empty states and preserve existing queue eligibility and permissions. A feed of upcoming interviews must be labeled as remaining today rather than implying a complete day's history.

Group Applications, Offers and Pipeline within one supporting panel, using section dividers. Label displayed queue lengths as “shown”; distinguish personal work from visible recruiting queues and application volume. Later personal interviews belong in Coming up without repeating today's schedule. Use a contextual agent-settings link when permitted, rather than an agent roster or empty setup panel. Preserve successful Today sections when another read fails. A failed section has no count or empty-state claim: show a local retry and a concise partial-data notice. Omit forbidden sections and their counts. Gate feedback-writing and analytics actions by their corresponding permissions.

### Lists, records, and settings

Optional creation and enrollment forms use native disclosures so records remain discoverable. Group related forms into two columns where space allows, then stack at narrow widths. Settings uses one compact directory and shared section navigation, collapsed on mobile. Retain ordinary submitted input after errors; do not echo tokens or secret references. Put primary offer actions before lengthy field/approval context. The public careers page is the employer's brand page, not a working page. It follows the v1 careers look: a tall image hero with a direct Openings anchor, then optional about and culture sections with highlight cards, then the roles. It may use the organization's configured accent (`careers_accent_color`, `--careers-accent`) instead of the app accent, Instrument Serif for its display headings (scoped to `.careers-page`; never in working pages), and v1's ink palette in dark theme. Light theme keeps the shared tokens. Candidate tasks use a compact organization header, grouped form questions and explicit completed/unusable states.

Use tables for repeated comparable data, lists for queues, and grouped sections for records and settings. Keep filters, result counts, and bulk actions near the data. Use a detail pane when it preserves list context and fits the viewport; otherwise use a clearly titled detail page with a reliable return path.

Keep search and bounded filter controls in one aligned row on desktop and stack fields on narrow screens. Use a select for growing pool catalogs; put saved-search setup in a labeled disclosure. Label capped lists as results shown. Give horizontally scrolling result tables a descriptive region name and keyboard focus. Show selection and mutation controls only with their corresponding permissions.

Record pages lead with compact contact or stage context and the current hiring task. Person pages use Application history, Person details, Resume and Activity log as section tabs, defaulting to Application history when permitted. Render only the selected view; on narrow screens the tabs share the same single-row sideways scroll as other working pages. Application history shows each job, current stage, progression and outcome. Place Move candidate and Archive application dropdowns beside the name on person and application pages. Archive closes a selected job application with a required reason using the existing rejection or withdrawal outcome; keep the person and audited history. Person erasure is restricted to human owners, including when custom roles or delegated agents have broader grants. Successful stage/archive submissions redirect to a read view so refresh cannot repeat a write. Optional message/company forms and lengthy application answers use disclosures. Application history includes the next pending step, interview schedule, submitted and pending feedback, offers and stage history. Reuse application workflows in place and keep optional scheduling and long feedback in disclosures. Person details provides inline contact and company editing for permitted recruiters and hiring managers; keep broader person-management controls separately authorized. The person Resume tab opens the in-app viewer immediately and offers Upload to replace the current resume; applications keep Resume after pipeline context. Provide page, zoom and fit-width controls and keep Download available. The dedicated Resume tab has no Close control; the application disclosure can close. Preserve historical uploads and show replacement scan states explicitly. Keep loading, unavailable and security-scan states explicit, and omit file access without permission. Use readable local dates with a timezone and retain the original machine-readable timestamp. At narrow widths, supporting record columns follow the primary content. Preserve list filters, search query and pagination through record actions and sibling review, using only validated local return destinations. Keep the job pipeline reachable alongside an application’s list return.

Job workspaces use the shared chrome (context chips, section tabs, filter segments) with a readable pipeline and grouped settings. In-page settings jumps use filter segments. Place candidate selection and move destinations above the board. Wide boards and result tables scroll within named, keyboard-focusable regions; cards wrap long identifiers and retain touch-sized selection targets. Existing posting editors and organization requirements use disclosures; keep the active draft open after validation or question edits. Separate application links from editing controls and preserve posting versions, audiences and saved question snapshots.

## Interaction and scrolling contract

| Action | Expected behavior |
| --- | --- |
| Select operation, experiment, or local tab | Update the working region without a forced page jump; preserve visible context. Shorter content may naturally clamp the previous scroll offset. |
| Run request or command | Keep input stable; show loading, completion, or error beside the action and in the result region |
| Result arrives | Do not steal focus or automatically scroll the page; announce completion accessibly and refresh related records independently |
| Open a different page | Start at its meaningful content header; preserve selection in the URL where appropriate |
| Follow an explicit anchor or View response link | Scroll to the named destination, clear of sticky UI |
| Browser Back/Forward | Restore prior route, selection, and scroll position within the available document range; recover drafts only within the workflow’s valid scope. Never rerun a request. |
| Expand details | Reveal content locally; retain focus on the disclosure control |

Prefer one main document scroll. Independently scrollable navigation, wide tables, code editors, and large responses are allowed when they solve a real overflow problem. Label them, make them keyboard accessible, and avoid unnecessary fixed heights or multiple nested vertical scrollers. Horizontal overflow belongs to a table or code region, never the whole page.

Do not use unconditional `scrollIntoView`, route hash changes, or autofocus to move people into a selected experiment. Use focus with scroll prevention for same-page updates when focus movement is needed. True page navigation may move focus to the new main heading; dialogs and validation errors may move focus deliberately to help the user complete the task. Avoid animated layout shifts. Respect reduced-motion preferences.

Associate each asynchronous result with the request and context that produced it. Selection changes must not relabel previous output as a new operation's response. Superseded execution, inspection, or refresh responses must not overwrite the active context or newer state. Define whether editing/selection is locked during execution or safely separated from it. Preserve input on errors; distinguish known failure from an unknown write outcome without automatically retrying an uncertain write. Announce concise completion status without moving focus or reading the whole response.

## Shared components and copy

Define shared variants for buttons, form fields, tabs, badges, tables, queue rows, panels, disclosures, empty states, loading states, and errors. Reuse their sizes, padding, focus treatment, and semantics across docs, lab, and app pages.

- Buttons name the action: Review applicants, Write feedback, Run request, Copy response.
- Fields have persistent labels; placeholders supply examples rather than replacing labels.
- Tabs expose their selected state and follow the keyboard behavior appropriate to tabs. Page-navigation links remain links.
- Empty states explain the current scope and give one useful next step when available. Filter unauthorized objects before serializing non-null lists so one hidden record cannot fail an otherwise usable page. Distinguish empty, failed, and permission-unavailable content; a failed section must not imply zero work. Counts state whether they describe displayed results or authoritative totals, and use the same scope as their linked destinations.
- Errors explain what failed and how to recover; preserve input. Keep field errors beside the field and request errors beside the result.
- Loading states reserve enough space to prevent disruptive shifts and prevent accidental duplicate execution.
- Visible focus indicators, accessible names, and sufficient contrast are required. Target WCAG AA: 4.5:1 for normal text, 3:1 for large text and meaningful control boundaries/indicators.
- Use concise, factual copy. Technical details belong in developer workflows where they help someone act; recruiter workflows use recruiting language.

## Implementation and verification

Implement this standard in shared tokens and components, then migrate pages. A markdown file alone cannot enforce consistency.

Shared tokens own visual roles; shared components own control styling and semantics; page compositions own task-specific arrangement. Scope styles to their intended surfaces and check shared changes against representative consumers, including public forms and overlays. Temporary aliases and migration sequencing belong in the execution plan.

For every affected surface, verify:

- Consistent text roles, colors, controls, and spacing; no page-specific visual system.
- At 1440×900 and 1280×800, meaningful working content appears without scrolling past oversized introductory blocks. Common lab selection/input/action and result status fit naturally; long data may still require scrolling.
- At 390×844 and 320 CSS-pixel width, content remains readable and operable without page-level horizontal overflow. Section tabs and filter segments use a single sideways-scrolling row or segmented track; record a wrap-vs-scroll verdict for every such row on every page. A page that passes the overflow check but wraps its filters into multiple rows is not a mobile pass. Verify 200% text enlargement and reflow equivalent to a 1280px viewport at 400% browser zoom; tables and code may overflow within their own accessible regions. Navigation and essential actions remain reachable, and editable mobile fields avoid forced focus zoom.
- Light and dark themes, keyboard navigation, visible focus, loading, error, empty, and long-content states work. Check normal, hover, pressed, selected, disabled, and status treatments against their rendered surfaces; modal controls return focus reliably.
- Lab selection does not cause unexpected page movement. Execution preserves input and focus; completion remains visible or reachable through an explicit action. Back/Forward restores valid context without executing. Unfinished input remains recoverable within the workflow’s declared boundaries, and late responses cannot overwrite a new context.
- Docs retain their topic organization and reading layout. Today keeps actionable work ahead of supporting context.
- Existing data, permissions, routes, and actions continue to function.

Use the project's Playwright/browser checks for affected interactions and existing type checks/tests appropriate to the change. Capture representative desktop and mobile screenshots for review, using realistic long content and failure states. Check both sides of layout collapse thresholds and record manual input-focus or browser-zoom checks when the harness cannot reproduce them. Do not treat token compliance alone as proof of a usable layout.

When an intentional exception is needed, record its surface, user benefit, and verification here. Update shared rules when a pattern should apply broadly instead of adding another page-specific convention.
