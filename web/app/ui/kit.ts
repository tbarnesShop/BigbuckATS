/**
 * Shared recruiter UI kit. Class names and layout shapes follow Big Buck's
 * live stylesheet (app-shell, page-head, chip tones, pills, tabs, cards,
 * section-card, table, queue, split / side-col, button variants). Colors
 * resolve through the custom properties in tokens.ts — this file does not
 * introduce a second palette.
 */
export const kitCss = `
@layer bb-kit {
:root {
  --paper: var(--bb-bg);
  --paper-2: var(--bb-surface-subtle);
  --surface: var(--bb-surface);
  --surface-sunk: var(--bb-surface-subtle);
  --ink: var(--bb-text);
  --ink-soft: var(--bb-text);
  --on-ink: var(--bb-on-accent);
  --muted: var(--bb-text-muted);
  --text-2: var(--bb-text-muted);
  --line: var(--bb-border);
  --line-soft: var(--bb-border);
  --accent: var(--bb-accent);
  --accent-deep: var(--bb-accent);
  --accent-soft: var(--bb-accent-subtle);
  --on-accent: var(--bb-on-accent);
  --danger: var(--bb-danger);
  --danger-bg: var(--bb-danger-bg);
  --ok-bg: var(--bb-success-bg);
  --ok-fg: var(--bb-success);
  --warn-bg: var(--bb-warning-bg);
  --warn-fg: var(--bb-warning);
  --bad-bg: var(--bb-danger-bg);
  --bad-fg: var(--bb-danger);
  --plain-bg: var(--bb-accent-subtle);
  --plain-fg: var(--bb-text);
  --radius: var(--bb-panel);
  --shadow: var(--bb-shadow);
  --nav-w: var(--bb-navWidth);
  --nav-bg: var(--bb-surface);
  --nav-ink: var(--bb-text);
  --nav-muted: var(--bb-text-muted);
  --nav-hover: var(--bb-accent-subtle);
  --nav-active: var(--bb-accent-subtle);
  --nav-line: var(--bb-border);
  --table-head: var(--bb-surface-subtle);
  --focus: none;
  --cmd-backdrop: var(--bb-overlay);
  --font-sans: var(--bb-font-body);
  --font-mono: var(--bb-font-code);
}
body {
  font-family: var(--font-sans);
  font-size: var(--bb-type-body);
  line-height: 1.45;
}
a { color: inherit; text-decoration: none; }
.app-shell {
  display: grid;
  grid-template-columns: var(--nav-w) minmax(0, 1fr);
  min-height: 100vh;
  background: var(--paper);
}
.app-nav {
  position: sticky;
  top: 0;
  align-self: start;
  height: 100vh;
  height: 100dvh;
  background: var(--nav-bg);
  color: var(--nav-ink);
  padding: max(1.15rem, env(safe-area-inset-top)) 0.85rem 1.15rem max(0.85rem, env(safe-area-inset-left));
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  border-right: 1px solid var(--nav-line);
  overflow: hidden;
  box-sizing: border-box;
}
.app-nav-brand {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  flex: none;
  width: 100%;
}
.app-nav-brand-actions {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  flex: none;
}
.app-nav-desktop {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  flex: 1 1 auto;
  min-height: 0;
}
.nav-group { display: contents; }
.app-nav-list {
  display: grid;
  gap: 0.2rem;
  flex: 1 1 auto;
  min-height: 0;
  align-content: start;
  overflow-y: auto;
}
.brand-mark {
  white-space: nowrap;
  display: inline-flex;
  align-items: center;
  gap: 0.65rem;
  font-family: var(--font-sans);
  font-weight: 600;
  letter-spacing: -0.03em;
  color: inherit;
  text-decoration: none;
  min-width: 0;
}
a.brand-mark:hover { opacity: 0.85; }
.app-nav .brand-mark {
  color: var(--nav-ink);
  padding: 0.15rem 0.45rem;
}
.brand-mark .word {
  font-size: 1.15rem;
  color: var(--accent);
}
.app-nav a,
.nav-drawer a {
  padding: 6px 12px;
  min-height: var(--bb-controlHeight);
  box-sizing: border-box;
  border-radius: var(--bb-control);
  color: var(--nav-muted);
  font-weight: 550;
  text-decoration: none;
}
.app-nav a:hover,
.nav-drawer a:hover {
  background: var(--nav-hover);
  color: var(--nav-ink);
}
.app-nav .nav-link,
.nav-drawer .nav-link {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 44px;
  box-sizing: border-box;
}
.app-nav a[aria-current="page"],
.nav-drawer a[aria-current="page"] {
  background: var(--nav-active);
  color: var(--nav-ink);
}
.nav-link-inner {
  display: inline-flex;
  align-items: center;
  gap: 0.65rem;
}
.nav-link-inner svg {
  flex: none;
  color: currentColor;
  opacity: 0.85;
}
.app-nav a[aria-current="page"] .nav-link-inner svg,
.nav-drawer a[aria-current="page"] .nav-link-inner svg {
  opacity: 1;
}
.nav-sub {
  display: grid;
  gap: 0.1rem;
  margin: 0.15rem 0 0.35rem;
  padding-left: 0.55rem;
}
.nav-sub-link {
  display: block;
  padding: 0.45rem 0.7rem 0.45rem 1.55rem;
  border-radius: var(--bb-control);
  color: var(--nav-muted);
  font-weight: 550;
  font-size: 0.92rem;
  min-height: 40px;
  box-sizing: border-box;
}
.nav-sub-link:hover {
  background: var(--nav-hover);
  color: var(--nav-ink);
}
.nav-sub-link[aria-current="page"] {
  background: var(--nav-active);
  color: var(--nav-ink);
}
.nav-foot {
  margin-top: auto;
  display: grid;
  gap: 0.75rem;
  flex: none;
}
.lens {
  border: 1px solid var(--nav-line);
  border-radius: var(--radius);
  padding: 0.75rem;
  display: grid;
  gap: 0.2rem;
  font-size: 0.85rem;
  color: var(--nav-muted);
}
.lens strong {
  color: var(--nav-ink);
  font-weight: 550;
}
@container (max-width: 700px) {
  .page-head { align-items: flex-start; flex-direction: column; }
  .page-head-aside { position: relative; width: 100%; flex: none; }
  .page-head-aside .create-menu, .command-bar { position: static; }
  .command-list { left: 0; right: auto; width: min(22rem, 100%); box-sizing: border-box; }
  .create-menu-panel { right: 0; width: min(18rem, 100%); box-sizing: border-box; }
}
.lens .eyebrow { color: var(--nav-muted); }
.nav-signout {
  width: 100%;
  color: var(--nav-muted);
  border-color: var(--nav-line);
}
.nav-menu-btn {
  display: none;
  appearance: none;
  align-items: center;
  gap: 0.4rem;
  min-height: 44px;
  padding: 0 0.75rem;
  border: 1px solid var(--bb-control-border);
  border-radius: var(--bb-control);
  background: transparent;
  color: var(--nav-ink);
  font: inherit;
  font-weight: 600;
  font-size: 0.92rem;
  cursor: pointer;
}
.nav-menu-btn:hover { background: var(--nav-hover); }
.nav-drawer { display: none; position: relative; }
.nav-menu-btn { list-style: none; }
.nav-menu-btn::marker { content: ''; }
.nav-menu-btn::-webkit-details-marker { display: none; }
.nav-drawer-panel {
  display: none;
  position: absolute;
  inset: 100% 0 auto auto;
  width: min(20rem, calc(100vw - 32px));
  max-width: none;
  max-height: calc(100dvh - 32px);
  margin: 8px 0 0;
  background: var(--nav-bg);
  color: var(--nav-ink);
  border: 1px solid var(--nav-line);
  box-shadow: var(--shadow);
  flex-direction: column;
  gap: 16px;
  padding: 16px;
  box-sizing: border-box;
  overflow: auto;
  overscroll-behavior: contain;
}
.nav-drawer[open] .nav-drawer-panel[open] { display: flex; }
.nav-drawer[data-enhanced] .nav-drawer-panel {
  position: fixed;
  inset: 0 auto 0 0;
  height: 100dvh;
  max-height: 100dvh;
  margin: 0;
  padding: max(16px, env(safe-area-inset-top)) 16px max(16px, env(safe-area-inset-bottom));
}
.nav-drawer-panel::backdrop { background: var(--cmd-backdrop); }
html:has(.nav-drawer-panel:modal) { overflow: hidden; }
.nav-drawer-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex: none; }
.nav-drawer-title { margin: 0; font-size: var(--bb-type-section); }
.nav-drawer-close { flex: none; min-height: 44px; cursor: pointer; }
.nav-drawer:not([data-enhanced]) .nav-drawer-close { display: none; }
.nav-drawer-foot { margin-top: auto; }
.nav-drawer-shortcuts {
  display: grid; gap: 4px; margin: 8px 0 16px; padding: 12px 0 0;
  border-top: 1px solid var(--nav-line, var(--line));
}
.app-main {
  padding: 24px max(24px, env(safe-area-inset-right)) 32px 24px;
  min-width: 0;
  container-type: inline-size;
}
.app-main > *,
.split,
.stack > * { min-width: 0; }
.page-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1rem;
}
.page-head > div:first-child { min-width: 0; overflow-wrap: anywhere; }
.page-head h1 {
  font-family: var(--font-sans);
  font-size: var(--bb-type-page);
  font-weight: 600;
  letter-spacing: -0.03em;
  color: var(--ink);
  margin: 0;
  line-height: 1.25;
}
.page-head .sub { color: var(--muted); margin: 0.25rem 0 0; }
.page-head-aside {
  display: flex;
  align-items: center;
  flex: 0 1 28rem;
  min-width: 0;
  gap: 0.5rem;
}
.page-head-aside .create-menu > summary {
  display: inline-flex;
  box-sizing: border-box;
  min-height: 36px;
  white-space: nowrap;
}
.eyebrow {
  font-size: 0.75rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-2);
  font-weight: 550;
  margin: 0 0 0.25rem;
}
.sub { color: var(--muted); }
.mute { margin: 0 0 1rem; line-height: 1.55; }
.stack { display: grid; gap: 1rem; align-content: start; }
.btn {
  appearance: none;
  border: 1px solid transparent;
  border-radius: var(--bb-control);
  padding: 6px 12px;
  min-height: var(--bb-controlHeight);
  box-sizing: border-box;
  cursor: pointer;
  font: inherit;
  font-weight: 600;
  text-decoration: none;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  transition: background var(--bb-motion-control), border-color var(--bb-motion-control), color var(--bb-motion-control);
}
.btn-primary { background: var(--accent); color: var(--on-accent); }
.btn-primary:hover { background: var(--bb-accent-hover); color: var(--on-accent); }
.btn-primary:active { background: var(--bb-accent-pressed); }
.btn-ghost {
  background: transparent;
  border-color: var(--bb-control-border);
  color: var(--ink);
}
.btn-ghost:hover { background: var(--surface-sunk); }
.btn-dark { background: var(--accent); color: var(--on-accent); }
.btn-dark:hover { background: var(--bb-accent-hover); }
.btn-dark:active { background: var(--bb-accent-pressed); }
.btn-small { padding: 0.4rem 0.75rem; font-size: var(--bb-type-meta); }
.btn-icon { min-width: 38px; padding-left: 0.55rem; padding-right: 0.55rem; }

.btn:disabled { background: var(--bb-disabled-bg); color: var(--bb-disabled); border-color: var(--bb-control-border); cursor: not-allowed; }
.theme-switch { display: flex; gap: 0.2rem; flex-wrap: wrap; }
.app-nav .theme-switch-bar { display: none; }
.theme-switch .theme-to-light { display: none; }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) .theme-switch .theme-to-dark { display: none; }
  :root:not([data-theme="light"]) .theme-switch .theme-to-light { display: inline-flex; }
}
:root[data-theme="dark"] .theme-switch .theme-to-dark { display: none; }
:root[data-theme="dark"] .theme-switch .theme-to-light { display: inline-flex; }
.theme-switch button.theme-to-dark, .theme-switch button.theme-to-light { width: var(--bb-controlHeight); padding: 0; }
.theme-switch button svg { width: 18px; height: 18px; }
.theme-switch button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  appearance: none;
  border: 1px solid var(--bb-control-border);
  background: transparent;
  color: var(--nav-muted);
  font: inherit;
  font-size: var(--bb-type-badge);
  letter-spacing: normal;
  text-transform: none;
  padding: 0.35rem 0.5rem;
  border-radius: var(--bb-control);
  cursor: pointer;
  min-height: var(--bb-controlHeight);
  min-width: 44px;
}
.create-menu { position: relative; flex: none; }
.create-menu > summary {
  display: list-item;
  list-style: none;
  width: fit-content;
  cursor: pointer;
  user-select: none;
}
.create-menu > summary::marker { content: ''; }
.create-menu > summary::-webkit-details-marker { display: none; }
.create-menu-panel {
  position: absolute;
  right: 0;
  top: calc(100% + 0.4rem);
  z-index: 40;
  min-width: 220px;
  max-width: calc(100vw - 2rem);
  padding: 0.35rem;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: var(--radius);
  box-shadow: var(--shadow);
  display: grid;
  gap: 0.15rem;
}
.create-menu-item {
  display: grid;
  gap: 0.15rem;
  padding: 0.7rem 0.8rem;
  border-radius: 8px;
  color: var(--ink);
  min-height: 44px;
  align-content: center;
  text-decoration: none;
  font-weight: 600;
}
.create-menu-item:hover { background: var(--paper-2); }
.create-menu-item .hint {
  font-size: var(--bb-type-badge);
  color: var(--muted);
  font-weight: 400;
}
.chip {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: var(--bb-type-badge);
  font-weight: 550;
  padding: 0.15rem 0.5rem;
  border-radius: 6px;
  background: var(--plain-bg);
  color: var(--plain-fg);
  white-space: nowrap;
}
.chip-ok { background: var(--ok-bg); color: var(--ok-fg); }
.chip-warn { background: var(--warn-bg); color: var(--warn-fg); }
.chip-bad { background: var(--bad-bg); color: var(--bad-fg); }
.chip-info { background: var(--accent-soft); color: var(--accent-deep); }
.chip-outline, .chip-agent { background: var(--surface); color: var(--ink); }
.chip-outline { border: 1px solid var(--line); }
.chip-agent { border: 1px dashed var(--text-2); }
.chip-row { display: flex; flex-wrap: wrap; gap: 0.4rem; }
.pill {
  appearance: none;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  min-height: 36px;
  padding: 0 0.8rem;
  border-radius: 999px;
  border: 1px solid var(--bb-control-border);
  background: var(--surface);
  color: var(--ink);
  font: inherit;
  font-size: 0.88rem;
  cursor: pointer;
  text-decoration: none;
}
/* Pills remain for rare chip-like actions only. Selected local nav uses .tabs / .filter-segments. */
.pills { display: flex; flex-wrap: wrap; gap: 0.4rem; }
/* Local nav rows (DESIGN.md): one sideways-scrolling line on narrow screens with a right-edge fade.
   Summary chips (div.chip-row) are not filters and may wrap. Pages add no private scroll rules. */
@media (max-width: 700px) {
  :is(.tabs, .filter-segments, .step-track, .list-pagination) {
    -webkit-mask-image: linear-gradient(90deg, #000 calc(100% - 32px), transparent);
    mask-image: linear-gradient(90deg, #000 calc(100% - 32px), transparent);
  }
}
/* Quiet segmented filter: one track, flat segments, chosen segment raised. Empty options recede. */
.filter-segments {
  display: inline-flex; flex-wrap: nowrap; gap: 2px; max-width: 100%; box-sizing: border-box;
  padding: 3px; border-radius: 10px; background: var(--surface-sunk); border: 1px solid var(--line);
  overflow-x: auto; overscroll-behavior-x: contain; scrollbar-width: none;
  margin: 0 0 1rem;
}
.filter-segments::-webkit-scrollbar { display: none; }
.filter-segments .segment {
  appearance: none; display: inline-flex; align-items: center; gap: 6px;
  flex: 0 0 auto; white-space: nowrap; min-height: 44px; padding: 0 12px;
  border: 0; border-radius: 7px; background: transparent; color: var(--ink);
  font: inherit; font-size: 0.875rem; text-decoration: none; cursor: pointer;
}
.filter-segments .segment:hover { background: color-mix(in srgb, var(--surface) 60%, transparent); }
.filter-segments .segment[aria-current="page"] {
  background: var(--surface); color: var(--ink); font-weight: 600;
  box-shadow: 0 1px 2px rgb(0 0 0 / 0.12), 0 0 0 1px var(--line);
}
.filter-segments .segment[data-empty]:not([aria-current]) { color: var(--muted); }
.filter-segments .segment[data-empty]:not([aria-current]) .tab-count { opacity: 0.7; }
@media (max-width: 700px) {
  .filter-segments {
    display: flex; width: calc(100% + 32px); max-width: none; margin: 0 -16px 12px; border-radius: 0;
    border-width: 1px 0; padding: 3px 16px; scroll-padding-inline: 16px;
  }
}
.tabs {
  display: flex;
  gap: 0.25rem;
  border-bottom: 1px solid var(--line);
  overflow-x: auto;
  scrollbar-width: none;
  margin-bottom: 1rem;
}
.tabs::-webkit-scrollbar { display: none; }
.tab {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  min-height: 44px;
  padding: 0 0.75rem;
  margin-bottom: -1px;
  border-bottom: 2px solid transparent;
  color: var(--text-2);
  font-weight: 550;
  white-space: nowrap;
  text-decoration: none;
  background: transparent;
  font: inherit;
}
.tab:hover { color: var(--ink); }
.tab[aria-current="page"] {
  color: var(--ink);
  border-bottom-color: var(--accent);
}
.card, .section-card, .stat-card {
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: var(--radius);
  color: inherit;
  text-decoration: none;
}
.section-card { padding: var(--bb-space-lg); }
.section-card h2 { font-size: var(--bb-type-section); line-height: 1.35; margin: 0 0 12px; }
.stat-card {
  border-radius: var(--bb-panel);
  padding: 0.95rem 1.05rem;
  display: grid;
  gap: 0.35rem;
}
.cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 1rem;
}
.card {
  display: grid;
  gap: 0.35rem;
  padding: 0.75rem;
  border-width: 2px;
  border-color: transparent;
  text-align: left;
  width: 100%;
}
.table-wrap { overflow-x: auto; border-radius: var(--radius); }
/* List and record families: compact controls, independent table overflow, readable metadata. */
.list-workspace, .record-workspace { min-width: 0; }
.list-count { margin: 0 0 16px; color: var(--bb-text-muted); font-size: 13px; }
.list-filters { display: flex; flex-wrap: wrap; align-items: end; gap: 12px; margin: 0 0 16px; }
.list-filters .field { margin: 0; min-width: 0; flex: 0 1 240px; }
.list-filters .list-query { flex: 1 1 240px; max-width: 480px; }
.people-filters-more { flex: 1 1 100%; margin: 0; }
.people-filters-more > summary {
  display: inline-flex; align-items: center; min-height: 44px; color: var(--text-2); font-weight: 550;
}
.people-filters-advanced { margin: 12px 0 0; }
.list-save { margin-bottom: 16px; }
.list-save form { margin-top: 12px; }
.list-meta { display: block; color: var(--bb-text-muted); font-size: 13px; line-height: 1.4; margin-top: 4px; overflow-wrap: anywhere; }
.bulk-actions { padding-top: 12px; border-top: 1px solid var(--bb-border); }
.bulk-actions .list-meta { margin: 0; }
.list-workspace .table { min-width: 560px; }
.list-workspace .table th { font-size: 13px; }
.list-workspace .table td { overflow-wrap: anywhere; }
.list-workspace .selection-cell { width: 44px; text-align: center; }
.list-workspace .selection-cell input { width: 18px; height: 18px; }
.list-pagination {
  display: flex; flex-wrap: nowrap; align-items: center; gap: 8px;
  margin-top: 16px; overflow-x: auto; overscroll-behavior-x: contain; scrollbar-width: none;
}
.list-pagination::-webkit-scrollbar { display: none; }
.list-pagination .page-link,
.list-pagination .page-status {
  display: inline-flex; align-items: center; min-height: 36px; padding: 0 12px;
  border: 1px solid var(--bb-control-border); border-radius: 6px; background: var(--surface);
  color: var(--ink); font: inherit; font-size: 0.88rem; text-decoration: none; white-space: nowrap;
}
.list-pagination .page-status { border-color: var(--line); color: var(--muted); }
.list-pagination .page-link[aria-disabled="true"] { opacity: 0.45; pointer-events: none; }
@media (pointer: coarse) {
  .list-pagination .page-link, .list-pagination .page-status { min-height: 44px; }
}
/* Read-only progress through stages — not selectable nav. */
.step-track {
  display: flex; flex-wrap: nowrap; gap: 0.4rem; margin: 0 0 1.25rem;
  overflow-x: auto; overscroll-behavior-x: contain; scrollbar-width: none;
}
.step-track::-webkit-scrollbar { display: none; }
.step-track .step {
  display: inline-flex; align-items: center; gap: 0.35rem; flex: 0 0 auto;
  min-height: 32px; padding: 0 0.75rem; border-radius: 999px;
  border: 1px solid var(--line); background: var(--surface-subtle); color: var(--muted);
  font-size: 0.88rem; white-space: nowrap;
}
.step-track .step[aria-current="step"] {
  background: var(--bb-accent-subtle); color: var(--bb-text); border-color: var(--bb-accent); font-weight: 600;
}
.page-title-line { display: flex; align-items: center; flex-wrap: wrap; gap: 12px; }
.candidate-actions { display: flex; flex-wrap: wrap; gap: 8px; }
.record-action-menu { position: relative; font-size: 14px; font-weight: 400; }
.record-action-menu > summary { cursor: pointer; white-space: nowrap; }
.record-action-panel-wide { width: min(480px, calc(100vw - 48px)); }
.meta-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 12px 24px; margin: 0 0 12px; }
.meta-row dt { font-size: 12px; color: var(--muted); margin: 0 0 2px; }
.meta-row dd { margin: 0; }
.person-actions { display: flex; flex-wrap: wrap; gap: 8px; margin: 0 0 8px; }
.person-actions .record-action-panel { max-height: min(75vh, 640px); }
.record-action-panel { box-sizing: border-box; position: absolute; z-index: 20; top: calc(100% + 8px); left: 0; width: min(320px, calc(100vw - 48px)); padding: 16px; border: 1px solid var(--control-border); border-radius: 8px; background: var(--surface); box-shadow: 0 4px 16px rgb(0 0 0 / 0.12); max-height: min(65vh, 560px); overflow: auto; }
.candidate-action-group + .candidate-action-group { margin-top: 16px; padding-top: 16px; border-top: 1px solid var(--border); }
.candidate-action-group h3 { font-size: 14px; margin: 0 0 12px; overflow-wrap: anywhere; }
.candidate-action-group form + form { margin-top: 16px; }
@media (max-width: 600px) { .record-action-panel { width: min(280px, calc(100vw - 48px)); } .candidate-actions { width: 100%; } .candidate-actions .record-action-menu { flex: 1 1 150px; min-width: 0; } .candidate-actions .record-action-menu > summary { justify-content: center; } .record-action-menu:last-child .record-action-panel { left: auto; right: 0; } }
.record-section-tabs { margin-top: 16px; }
.record-section-tabs .tab { min-height: 44px; }
.person-applications { list-style: none; padding: 0; margin: 0; }
.person-application { padding: 16px 0 24px; border-bottom: 1px solid var(--border); }
.person-application:last-child { border-bottom: 0; }
.person-application-heading { display: flex; flex-wrap: wrap; align-items: start; justify-content: space-between; gap: 12px; }
.person-application-heading > div { min-width: 0; }
.person-application-title { font-size: 16px; font-weight: 600; overflow-wrap: anywhere; }
.person-stage-track { list-style: none; padding: 0; margin: 16px 0 0; display: flex; flex-wrap: wrap; gap: 12px 24px; }
.person-stage-track li { display: flex; align-items: center; gap: 8px; color: var(--text-muted); }
.person-stage-track li[aria-current="step"] { color: var(--accent); font-weight: 600; }
.person-stage-marker { width: 10px; height: 10px; border: 2px solid currentColor; border-radius: 50%; flex-shrink: 0; }
.person-stage-track li[data-complete] .person-stage-marker { background: currentColor; }
.candidate-next-step { margin-top: 16px; padding: 12px; border-left: 3px solid var(--accent); background: var(--surface-subtle); }
.candidate-next-step p { margin: 4px 0 0; }
.candidate-workflow { margin-top: 16px; }
.candidate-workflow > summary { font-weight: 600; cursor: pointer; }
.candidate-workflow .record-workspace { margin-top: 16px; }
.candidate-workflow .record-workspace h2 { font-size: 14px; }
.feedback-list { display: grid; gap: 8px; }
.record-workspace h3.feedback-heading { margin: 24px 0 12px; }
.feedback-interview { border: 1px solid var(--line); border-radius: var(--bb-panel); background: var(--surface); padding: 0 16px; }
.feedback-interview > summary, .feedback-unbooked { display: flex; flex-wrap: wrap; align-items: center; gap: 4px 12px; min-height: 48px; padding: 8px 0; }
.feedback-interview > summary { cursor: pointer; list-style: none; }
.feedback-interview > summary::-webkit-details-marker { display: none; }
.feedback-interview > summary::before { content: "▸"; color: var(--text-2); width: 0.8em; }
.feedback-interview[open] > summary::before { content: "▾"; }
.record-workspace .feedback-interview[open] > summary { margin-bottom: 4px; border-bottom: 1px solid var(--line); }
.feedback-unbooked { padding-left: calc(0.8em + 12px); }
.feedback-title { font-weight: 600; color: var(--ink); }
.feedback-when { margin-left: auto; color: var(--text-2); font-size: 13px; font-weight: 400; }
.feedback-interview[open] { padding-bottom: 16px; }
.record-workspace p.panel-roster, .panel-roster { margin: 12px 0; font-size: 13px; color: var(--ink); }
.panel-roster-label { color: var(--bb-text-muted); margin-right: 8px; }
.feedback-verdicts { display: inline-flex; flex-wrap: wrap; gap: 2px 14px; font-size: 13px; font-weight: 400; color: var(--bb-text-muted); }
.feedback-verdicts strong { font-weight: 600; color: var(--ink); }
.feedback-interview[open] > summary .feedback-verdicts { display: none; }
.record-workspace details.plan-extra { margin-top: 20px; }
.rubric-list { display: grid; gap: 8px; margin-top: 16px; }
.rubric-row > summary, .rubric-row.feedback-unbooked { row-gap: 8px; padding-block: 12px; }
.rubric-row.feedback-unbooked { padding-inline: 16px; }
.rubric-row .rubric-guidance { color: var(--bb-text-muted); font-size: 13px; font-weight: 400; }
.rubric-row .rubric-edit { margin-left: auto; color: var(--accent); font-size: 13px; font-weight: 500; }
.rubric-row[open] .rubric-edit { display: none; }
.rubric-row .chip-row { flex-basis: 100%; padding-left: calc(0.8em + 12px); }
.rubric-row.feedback-unbooked .chip-row { padding-left: 0; }
.rubric-row[open] > summary { border-bottom: 1px solid var(--line); margin-bottom: 16px; }
.rubric-row form { max-width: 60rem; }
.rubric-new > summary .feedback-title { color: var(--accent); }
.scorecard { padding: 12px 0; border-top: 1px solid var(--line); }
.scorecard > header { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
.scorecard-ratings { display: flex; flex-wrap: wrap; gap: 4px 24px; margin: 8px 0 0; }
.scorecard-ratings > div { display: flex; gap: 6px; font-size: 13px; }
.record-workspace .scorecard-ratings dt { color: var(--bb-text-muted); }
.record-workspace .scorecard-ratings dd { margin: 0; font-weight: 600; }
.scorecard-notes { margin: 8px 0 0; white-space: pre-wrap; overflow-wrap: anywhere; max-width: 72ch; }
.scorecard-edit { margin-top: 8px; }
.record-workspace .scorecard-edit > summary { cursor: pointer; font-weight: 500; font-size: 13px; color: var(--accent); }
.scorecard-own { margin-top: 4px; padding-top: 16px; border-top: 1px solid var(--line); }
.scorecard-own h4 { margin: 0 0 12px; font-size: var(--bb-type-section); }
.scorecard-form { max-width: 44rem; }
.scorecard-form > .field > select { max-width: 20rem; }
.scorecard-rubric { border: 0; padding: 0; margin: 0 0 4px; min-width: 0; }
.scorecard-rubric > legend { font-weight: 600; padding: 0; margin-bottom: 4px; }
.scorecard-rubric-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 0 16px; }
.field-optional { color: var(--text-2); font-weight: 400; }
.rubric-attributes { display: grid; gap: 8px; margin-bottom: 12px; }
.rubric-attribute { display: grid; grid-template-columns: minmax(0, 2fr) minmax(0, 3fr) auto; gap: 12px; align-items: end; }
.rubric-attribute .field { margin: 0; }
.rubric-attribute .check { min-height: 40px; display: inline-flex; align-items: center; gap: 12px; white-space: nowrap; }
.rubric-attribute .check label { display: inline-flex; align-items: center; gap: 6px; }
/* The attribute rows read as a table: column labels show once, on the first row. */
@media (min-width: 641px) {
  .rubric-attribute:not(:first-child) .field > span { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; }
}
@media (max-width: 640px) {
  .feedback-verdicts { flex-basis: 100%; padding-left: calc(0.8em + 12px); }
  .rubric-row .rubric-guidance { flex-basis: 100%; padding-left: calc(0.8em + 12px); }
  .rubric-row.feedback-unbooked .rubric-guidance { padding-left: 0; }
  .feedback-when { margin-left: 0; flex-basis: 100%; padding-left: calc(0.8em + 12px); }
  .rubric-attribute { grid-template-columns: 1fr; align-items: start; }
}
.profile-edit-form { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); align-items: end; gap: 12px; margin-top: 16px; }
.profile-edit-form > button { width: fit-content; }
.resume-upload { display: flex; flex-wrap: wrap; align-items: end; gap: 12px; padding: 0 0 16px; margin: 0 0 16px; border-bottom: 1px solid var(--border); }
.resume-upload .field { flex: 1 1 240px; }
.resume-upload input[type="file"] { max-width: 100%; min-width: 0; box-sizing: border-box; }
.resume-upload p { flex: 1 1 100%; margin: 0; }
.resume-viewer[data-fixed] > summary { display: none; }
@media (max-width: 600px) { .profile-edit-form { grid-template-columns: minmax(0, 1fr); } .resume-upload > button { width: 100%; } }
.resume-section { margin-bottom: 16px; }
.resume-files { list-style: none; padding: 0; margin: 0; }
.resume-files li { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px; padding: 8px 0; }
.resume-file-info { min-width: 0; flex: 1 1 200px; overflow-wrap: anywhere; }
.resume-actions { display: flex; flex-wrap: wrap; gap: 8px; }
.resume-viewer { flex: 1 1 100%; min-width: 0; }
.resume-viewer summary { width: fit-content; cursor: pointer; }
.resume-viewer-body { margin-top: 12px; }
.resume-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin-bottom: 8px; }
.resume-toolbar[hidden] { display: none; }
.resume-preview { width: 100%; box-sizing: border-box; max-width: 100%; overflow: auto; border: 1px solid var(--border); border-radius: 6px; background: var(--surface-subtle); }
.resume-sheet { position: relative; background: #fff; color-scheme: light; }
.resume-sheet canvas { display: block; }
/* PDF.js text-layer geometry; scoped to resume pages to preserve the app theme. */
.resume-sheet .textLayer { position: absolute; inset: 0; overflow: clip; line-height: 1; letter-spacing: normal; word-spacing: normal; text-align: initial; transform-origin: 0 0; text-size-adjust: none; forced-color-adjust: none; --min-font-size: 1; --text-scale-factor: calc(var(--total-scale-factor) * var(--min-font-size)); --min-font-size-inv: calc(1 / var(--min-font-size)); }
.resume-sheet .textLayer :is(span, br) { color: transparent; position: absolute; white-space: pre; cursor: text; transform-origin: 0 0; user-select: text; }
.resume-sheet .textLayer > :not(.markedContent), .resume-sheet .markedContent span:not(.markedContent) { z-index: 1; --font-height: 0; font-size: calc(var(--text-scale-factor) * var(--font-height)); --scale-x: 1; --rotate: 0deg; transform: rotate(var(--rotate)) scaleX(var(--scale-x)) scale(var(--min-font-size-inv)); }
.resume-sheet .markedContent { display: contents; }
.resume-sheet .textLayer ::selection { background: rgb(98 70 217 / 0.3); }

.resume-preview pre { white-space: pre-wrap; overflow-wrap: anywhere; padding: 16px; margin: 0; }
.resume-viewer [role="status"]:empty { display: none; }
.resume-viewer-close, .resume-viewer[open] .resume-viewer-open { display: none; }
.resume-viewer[open] .resume-viewer-close { display: inline; }
.record-summary { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px; margin: 0 0 24px; padding-bottom: 16px; border-bottom: 1px solid var(--bb-border); }
.record-workspace dt { color: var(--bb-text-muted); font-size: 13px; }
.record-workspace dd { margin: 4px 0 0; overflow-wrap: anywhere; }
.record-columns { display: grid; grid-template-columns: minmax(0, 2fr) minmax(240px, 1fr); gap: 24px; }
.record-columns > * { min-width: 0; }
.record-section { padding: 0 0 16px; border-bottom: 1px solid var(--bb-border); min-width: 0; }
.record-workspace h2, .record-workspace h3 { font-size: var(--bb-type-section); line-height: 1.35; margin: 0 0 12px; }
.record-workspace p.sub { font-size: 13px; margin: 0 0 12px; }
.record-workspace details > summary { font-weight: 600; }
.record-workspace details[open] > summary { margin-bottom: 12px; }
.record-workspace details form { margin-top: 12px; }
.record-workspace .section-count { margin-left: 8px; color: var(--bb-text-muted); font-size: 13px; font-weight: 400; }
.record-fields { margin: 0; display: grid; gap: 12px; }
.record-fields > div { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 12px; }
.record-fields dd { margin: 0; }
.record-rows, .record-timeline { list-style: none; padding: 0; margin: 0; }
.record-rows li, .record-timeline li { padding: 12px 0; border-bottom: 1px solid var(--bb-border); overflow-wrap: anywhere; }
.record-rows li:last-child, .record-timeline li:last-child { border-bottom: 0; }
.record-timeline time { display: block; color: var(--bb-text-muted); font-size: 13px; margin-top: 4px; }
.record-danger { margin-top: 24px; }
.record-danger > summary, .record-danger .btn { color: var(--bb-danger); }
.record-context { margin: 0 0 12px; font-size: 13px; }
.record-workspace .application-sections > .section-card { background: transparent; border: 0; border-bottom: 1px solid var(--bb-border); border-radius: 0; padding: 16px 0; }
.record-workspace .section-card .section-card { background: transparent; border: 0; border-top: 1px solid var(--bb-border); border-radius: 0; padding: 16px 0; margin-top: 16px; }
@media (min-width: 701px) { .record-workspace .pill { white-space: normal; } }
.record-workspace .hint, .record-workspace dl, .record-workspace .title { overflow-wrap: anywhere; }
@media (max-width: 960px) {
  .record-columns { grid-template-columns: minmax(0, 1fr); }
  .record-summary { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 600px) {
  .list-filters .field, .list-filters .list-query { flex: 1 1 100%; max-width: none; }
  .list-filters > .btn { flex: 1 1 auto; }
  .list-workspace .selection-cell { padding: 0; }
  .list-workspace .selection-cell input { width: 24px; height: 24px; margin: 10px; }
  .record-summary { gap: 12px; }
  .record-workspace .form-narrow { max-width: 100%; }
}
.table {
  width: 100%;
  border-collapse: collapse;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: var(--radius);
  overflow: hidden;
}
.table a { color: var(--accent-deep); font-weight: 600; }
.table td, .table th {
  text-align: left;
  padding: 0.5rem 0.75rem;
  border-bottom: 1px solid var(--line-soft);
  vertical-align: middle;
}
.table th {
  font-size: var(--bb-type-badge);
  text-transform: none;
  letter-spacing: normal;
  color: var(--muted);
  background: var(--table-head);
  font-weight: 600;
  white-space: nowrap;
}
.table tr:last-child td { border-bottom: 0; }
.table tr:hover td { background: color-mix(in srgb, var(--accent-soft) 55%, transparent); }
.queue {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.6rem;
}
.queue-item {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.85rem;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: var(--bb-panel);
  padding: 0.9rem 1rem;
}
.queue-item .body { flex: 1 1 220px; min-width: 0; display: grid; gap: 0.15rem; }
.queue-item .title { font-weight: 600; color: var(--ink); text-decoration: none; }
.queue-item .why, .queue-item .hint { color: var(--text-2); }
.queue-item .kind { min-width: 104px; justify-content: center; }
.queue-actions { display: flex; flex-wrap: wrap; gap: 0.4rem; justify-content: flex-end; }
.mono { font-family: var(--font-mono); font-size: 0.8rem; }
.pill .mono { opacity: 0.7; font-size: var(--bb-type-badge); }
.meta { color: var(--muted); font-size: var(--bb-type-meta); }
.checks { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.45rem; }
.checks li { display: flex; gap: 0.6rem; align-items: flex-start; line-height: 1.4; }
.checks a { font-weight: 550; }
.today-layout { display: grid; grid-template-columns: minmax(0, 2fr) minmax(280px, 1fr); gap: 24px; align-items: start; }
.today-main, .today-side { min-width: 0; }
.today-section { padding: 16px; scroll-margin-top: calc(var(--demo-banner-height, 0px) + 16px); }
.today-overview { padding: 0; overflow-wrap: anywhere; }
.today-overview > section + section { border-top: 1px solid var(--bb-border); }
.today-partial { padding: 12px 16px; margin: 0 0 16px; border: 1px solid var(--bb-control-border); border-radius: var(--bb-panel); color: var(--bb-warning); background: var(--bb-warning-bg); }
.today-section-failure p { margin: 12px 0 0; color: var(--bb-danger); }
.today-settings-link { margin: 0; padding: 0 16px; }
.today-section-heading { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; }
.today-section-heading h2 { margin: 0; font-size: 16px; line-height: 1.35; }
.today-count { flex: none; padding: 2px 8px; border-radius: 4px; background: var(--paper-2); color: var(--ink); font-size: 13px; font-weight: 600; }
.today-context { margin: 4px 0 16px; }
.today-empty { margin: 16px 0; color: var(--muted); }
.today-section-link { display: inline-block; margin: 12px 0 0; font-size: 14px; font-weight: 550; }
.today-rows { list-style: none; padding: 0; margin: 0; }
.today-rows > li { display: flex; align-items: center; gap: 16px; padding: 12px 0; border-top: 1px solid var(--line); }
.today-row-body { display: grid; gap: 4px; flex: 1; min-width: 0; overflow-wrap: anywhere; }
.today-row-title { font-weight: 600; }
.today-rows .btn { flex: none; }
.today-pipeline { list-style: none; padding: 0; margin: 12px 0 0; }
.today-pipeline li { display: grid; gap: 4px; padding: 12px 0; border-bottom: 1px solid var(--line); }
.today-pipeline a { font-weight: 550; overflow-wrap: anywhere; }
@media (max-width: 1100px) { .today-layout { grid-template-columns: minmax(0, 1fr); } }
@media (max-width: 768px) {
  .today-layout { gap: 16px; }
  .today-rows > li { flex-wrap: wrap; gap: 12px; }
  .today-row-body { flex-basis: 100%; }
  .today-rows .btn { min-height: 44px; box-sizing: border-box; }
}
.mark {
  flex: 0 0 22px;
  height: 22px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  font-size: 0.75rem;
  font-weight: 700;
  background: var(--ok-bg);
  color: var(--ok-fg);
}
.hub-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  justify-content: space-between;
  align-items: center;
}
.table td.actions { text-align: right; white-space: nowrap; }
.split {
  display: flex;
  flex-wrap: wrap;
  gap: 1.25rem;
  align-items: flex-start;
}
.split > .main-col { flex: 999 1 520px; min-width: 0; }
.split > .side-col {
  flex: 1 1 280px;
  min-width: 0;
  display: grid;
  gap: 0.85rem;
}
.empty {
  padding: 2rem;
  text-align: center;
  color: var(--muted);
  background: var(--surface);
  border: 1px dashed var(--line);
  border-radius: var(--radius);
}
.field { display: grid; gap: 0.35rem; margin-bottom: 0.85rem; }
.field > span { font-size: var(--bb-type-meta); color: var(--muted); font-weight: 550; }
.field input:not([type="checkbox"]):not([type="radio"]), .field select, .field textarea {
  font: inherit;
  font-size: 1rem;
  padding: 6px 12px;
  min-height: var(--bb-controlHeight);
  box-sizing: border-box;
  border: 1px solid var(--bb-control-border);
  border-radius: var(--bb-control);
  background: var(--surface);
  color: var(--ink);
}
.form-narrow { max-width: 32rem; }
.field :is(input,select,textarea) { max-width: 100%; min-width: 0; }
.field input:is([type="checkbox"],[type="radio"]) { width: 18px; height: 18px; accent-color: var(--bb-accent); }
.notice { color: var(--accent); font-weight: 600; margin: 0 0 1rem; }
.notice-bad { color: var(--danger); font-weight: 600; margin: 0 0 1rem; }
.notice-warn { color: var(--warn-fg); font-weight: 600; margin: 0 0 1rem; }
.command-link {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 1rem;
  color: inherit;
  text-decoration: none;
  width: 100%;
}
.command-link .title { font-weight: 600; font-size: 1.05rem; }
.back-link {
  display: inline-flex;
  align-items: center;
  margin: 0 0 0.35rem;
  color: var(--muted);
  font-size: 0.88rem;
  font-weight: 550;
  text-decoration: none;
}
.back-link:hover { color: var(--ink); }
.page-subhead {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin: -0.5rem 0 1rem;
}
.tab-count {
  font-variant-numeric: tabular-nums;
  font-size: var(--bb-type-badge);
  color: var(--muted);
  font-weight: 550;
}
.tab[aria-current="page"] .tab-count { color: inherit; }
.postings-workspace > .record-section { margin-bottom: 24px; }
.posting-links { display: flex; flex-wrap: wrap; gap: 8px 24px; }
.posting-links a { display: inline-flex; align-items: center; min-height: 44px; }
.pipeline-template { margin-top: 16px; }
.posting-row h3 { margin: 0; font-size: var(--bb-type-section); overflow-wrap: anywhere; }
.posting-heading { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; }
.posting-edit { margin-top: 16px; }
.posting-edit > summary, .posting-baseline > summary { cursor: pointer; font-weight: 550; }
.posting-edit[open] > summary { margin-bottom: 16px; }
.posting-fields { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; }
.posting-fields .field { margin: 0; min-width: 0; }
.posting-title, .posting-template { grid-column: 1 / -1; }
.posting-form { max-width: 760px; }
.question-editor { display: grid; gap: 16px; }
.question-row { min-inline-size: 0; margin: 0; padding: 16px 0; border: 0; border-top: 1px solid var(--line); }
.question-row legend { padding: 0 12px 0 0; font-weight: 600; font-size: var(--bb-type-meta); }
.question-fields { display: flex; flex-wrap: wrap; align-items: center; gap: 16px; }
.question-fields .field { flex: 1 1 220px; min-width: 0; }
.question-required { min-height: 44px; display: flex; align-items: center; }
.question-required span { display: flex; align-items: center; gap: 8px; }
.question-required input { width: 18px; height: 18px; }
@media (max-width: 700px) { .posting-fields { grid-template-columns: minmax(0, 1fr); } }
.job-workspace { min-width: 0; }
.job-settings { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 24px; }
.job-settings > * { min-width: 0; }
.job-settings > nav, .job-settings > #job-posting, .job-settings > #pipeline, .job-settings > #interview-plan { grid-column: 1 / -1; }
.plan-stage { border-top: 1px solid var(--line); padding: 0.6rem 0; }
.plan-stage > summary { font-weight: 600; cursor: pointer; min-height: 36px; display: flex; align-items: center; gap: 0.4rem; }
.offer-answer { display: grid; gap: 1rem; margin-top: 20px; max-width: 28rem; }
.offer-decline > summary { cursor: pointer; color: var(--muted); }
.job-settings .queue-item { flex-wrap: wrap; }
.pipeline-editor { min-width: 40rem; }
.pipeline-editor th, .pipeline-editor td:nth-child(3), .pipeline-editor td:nth-child(4) { white-space: nowrap; }
.pipeline-editor td { vertical-align: middle; }
.pipeline-editor th:nth-child(1), .pipeline-editor td:nth-child(1) { width: 2rem; }
.pipeline-editor .inline-form { flex-wrap: nowrap; }
.pipeline-editor .btn, .row-actions .btn { white-space: nowrap; }
.pipeline-editor .inline-form input { min-width: 10rem; }
.form-actions { display: flex; flex-wrap: wrap; align-items: center; gap: 12px; }
.board {
  position: relative;
  display: flex;
  flex-wrap: nowrap;
  gap: 0.75rem;
  overflow-x: auto;
  padding: 0.15rem 0.15rem 0.75rem;
  scroll-snap-type: x proximity;
}
.board-col {
  /* Columns grow to share wide screens, so six stages fit at 1920px without scrolling. */
  flex: 1 0 min(15rem, 100%);
  max-width: 20rem;
  width: min(15rem, 100%);
  min-width: 0;
  scroll-snap-align: start;
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  min-height: 12rem;
  background: var(--surface-sunk);
  border-radius: var(--radius);
  padding: 0.75rem;
  box-sizing: border-box;
}
.board-col-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.5rem;
  min-height: 2.8em;
  overflow-wrap: anywhere;
  margin: 0;
  font-size: var(--bb-type-badge);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--muted);
  font-weight: 600;
}
.board-col-count { font-weight: 550; letter-spacing: 0; text-transform: none; }
@media (min-width: 1400px) { .board-scroll-hint[data-columns="5"] { display: none; } }
@media (min-width: 1700px) { .board-scroll-hint[data-columns="6"] { display: none; } }
@media (min-width: 1960px) { .board-scroll-hint[data-columns="7"] { display: none; } }
.board-cards { display: grid; gap: 0.5rem; align-content: start; margin: 0; padding: 0; list-style: none; }
.board-empty { font-size: 0.85rem; color: var(--muted); padding: 0.35rem 0.15rem; }
.board-cards:has(.board-card) > .board-empty { display: none; }
/* Drag and drop (ui/public/drag-move.tsx). The cursor only changes once the script is ready. */
[data-drag-ready] [data-drag-item] { cursor: grab; }
[data-drag-ready] [data-drag-item]:active { cursor: grabbing; }
[data-drag-item][data-dragging] { opacity: 0.45; }
.board-col[data-drop-active] { outline: 2px solid var(--accent); outline-offset: -2px; background: var(--accent-soft, var(--surface-sunk)); }
.board-col[data-drop-zone] .board-cards { flex: 1 1 auto; }
[data-drag-root][aria-busy="true"] { pointer-events: none; }
[data-drag-item][data-drop-edge="before"] { box-shadow: 0 -3px 0 0 var(--accent); }
[data-drag-item][data-drop-edge="after"] { box-shadow: 0 3px 0 0 var(--accent); }
.board-card {
  display: grid;
  gap: 0.25rem;
  padding: 0.75rem;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: var(--bb-control);
}
.board-card:has(input:checked) {
  border-color: var(--accent);
  box-shadow: 0 0 0 1px var(--accent);
}
.board-card-top { display: flex; align-items: flex-start; gap: 0.45rem; }
.board-card-name { min-width: 0; overflow-wrap: anywhere; font-weight: 600; color: var(--accent-deep); text-decoration: none; }
.board-card-name:hover { text-decoration: underline; }
.board-card-meta, .board-card-age { overflow-wrap: anywhere; margin: 0; font-size: var(--bb-type-badge); color: var(--muted); }
.board-card-scheduled { display: flex; flex-wrap: wrap; align-items: center; gap: 0.3rem; margin: 0.15rem 0 0; font-size: var(--bb-type-badge); color: var(--ink); overflow-wrap: anywhere; }
.schedule-banner { display: flex; flex-wrap: wrap; align-items: center; gap: 0.4rem; margin: 0.5rem 0; padding: 0.5rem 0.75rem; border: 1px solid var(--line); border-radius: var(--bb-panel, 8px); background: var(--surface); }
.row-actions { display: flex; flex-wrap: wrap; align-items: center; gap: 0.35rem; }
.row-actions form { margin: 0; }
.inline-form { display: flex; flex-wrap: wrap; align-items: center; gap: 0.35rem; margin: 0; }
.inline-form input, .inline-form select { min-width: 10rem; }
.form-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr)); gap: 0 1rem; }
.posting-details textarea { width: 100%; font: inherit; }
.queue-item .row-actions { margin-left: auto; }
.sequence-steps { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.5rem; }
.sequence-step .step-grip { color: var(--muted); font-size: 1.1rem; line-height: 1; user-select: none; }
.sequence-step .settings-edit:not([open]) { flex-basis: auto; }
.sequence-step .settings-edit > summary { list-style: none; }
.sequence-step .settings-edit form, .step-add form { display: grid; gap: 0.75rem; justify-items: start; }
.sequence-step .settings-edit form .field, .step-add form .field { justify-self: stretch; margin: 0; }
.sequence-step .settings-edit > summary::-webkit-details-marker { display: none; }
.step-add { margin: 1rem 0 1.5rem; border: 1px solid var(--line); border-radius: var(--bb-panel); background: var(--surface); }
.step-add h3 { margin: 0; padding: 0.75rem 1rem; font-size: 1rem; }
.step-add details { border-top: 1px solid var(--line); padding: 0 1rem; }
.step-add summary { cursor: pointer; min-height: 44px; align-content: center; font-weight: 600; }
.step-add details[open] { padding-bottom: 1rem; }
.settings-row { flex-wrap: wrap; }
.settings-edit { flex-basis: 100%; }
.settings-edit > summary { display: inline-flex; margin: 0.25rem 0; }
.settings-edit[open] { padding: 0.5rem 0; border-top: 1px solid var(--line); }
.settings-edit form + form { margin-top: 0.5rem; }
.plain-list { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.25rem; }
.field-list { display: grid; grid-template-columns: repeat(auto-fit, minmax(11rem, 1fr)); gap: 0.75rem 1rem; margin: 0 0 1rem; }
.field-list dt { font-size: var(--bb-type-badge); color: var(--muted); }
.field-list dd { margin: 0.15rem 0 0; font-weight: 600; }
.checklist { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.5rem; }
.checklist-item { display: grid; grid-template-columns: 1.6rem minmax(0, 1fr); gap: 0.5rem; padding: 0.6rem 0; border-bottom: 1px solid var(--line); }
.checklist-mark { display: inline-flex; width: 1.4rem; height: 1.4rem; align-items: center; justify-content: center; border-radius: 50%; border: 1px solid var(--line); font-size: 0.8rem; }
.checklist-item.is-done .checklist-mark { background: var(--ok-bg); color: var(--ok-fg); border-color: transparent; }
.checklist-item.is-current .checklist-mark { border-color: var(--accent); color: var(--accent-deep); }
.checklist-body { display: grid; gap: 0.25rem; }
.checklist-body .sub { margin: 0; }
.board-select { position: relative; display: flex; flex: 0 0 28px; min-height: 28px; align-items: center; justify-content: center; }
.board-card input { margin: 0; width: 18px; height: 18px; }
@media (max-width: 700px) {
  .job-settings { grid-template-columns: minmax(0, 1fr); }
  .board-select { flex-basis: 44px; min-height: 44px; }
  .board-card input { width: 24px; height: 24px; }
}
.move-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  margin: 0 0 12px;
  padding: 0.85rem 1rem;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: var(--radius);
  min-inline-size: 0;
}
.move-bar legend {
  width: 100%;
  padding: 0;
  margin: 0 0 0.15rem;
  font-size: var(--bb-type-meta);
  font-weight: 550;
  color: var(--muted);
}
a:focus-visible,
button:focus-visible,
input:focus-visible,
select:focus-visible,
textarea:focus-visible,
[role="region"][tabindex]:focus-visible,
summary:focus-visible {
  outline: 2px solid var(--bb-focus);
  outline-offset: 2px;
  box-shadow: none;
}
.skip-link {
  position: absolute;
  left: 0.75rem;
  top: -4rem;
  z-index: 80;
  background: var(--accent);
  color: var(--on-accent);
  padding: 0.55rem 0.8rem;
  border-radius: 8px;
  font-weight: 600;
}
.skip-link:focus { top: 0.75rem; }
.demo-frame { --demo-banner-height: 48px; }
.demo-frame .app-shell { min-height: calc(100dvh - var(--demo-banner-height)); }
.demo-frame .app-nav { top: var(--demo-banner-height); height: calc(100dvh - var(--demo-banner-height)); }
.demo-frame main [id], .demo-frame #main { scroll-margin-top: calc(var(--demo-banner-height) + 16px); }
.demo-workspace-banner {
  position: sticky; top: 0; z-index: 31;
  display: flex; align-items: center; flex-wrap: wrap; gap: 8px 24px;
  min-height: 48px; box-sizing: border-box;
  padding: 6px max(24px, env(safe-area-inset-right)) 6px max(24px, env(safe-area-inset-left));
  border-bottom: 1px solid var(--bb-control-border);
  background: color-mix(in srgb, var(--bb-accent) 8%, var(--bb-surface)); color: var(--bb-text); font: 13px/1.45 var(--font-sans);
}
.demo-workspace-identity { display: flex; align-items: baseline; flex-wrap: wrap; gap: 4px 12px; min-width: 0; }
.demo-workspace-identity strong { font-size: 13px; font-weight: 600; }
.demo-workspace-persona { overflow-wrap: anywhere; }
.demo-workspace-desktop-meta { margin-left: auto; color: var(--bb-text-muted); }
.demo-workspace-actions { display: flex; align-items: center; flex-wrap: wrap; gap: 4px 12px; }
.demo-workspace-actions a, .demo-workspace-details summary {
  display: inline-flex; align-items: center; justify-content: center; gap: 8px;
  min-height: 36px; box-sizing: border-box; border-radius: 6px; font-weight: 500; cursor: pointer;
}
.demo-workspace-actions > a { padding: 0 8px; }
.demo-workspace-actions a:hover, .demo-workspace-details summary:hover { text-decoration: underline; text-underline-offset: 3px; }
.demo-workspace-back { border: 1px solid var(--bb-control-border); background: var(--bb-surface); }
.demo-workspace-details summary { padding: 0 8px; }
.demo-workspace-details { position: relative; }
.demo-workspace-details summary::after { content: '⌄'; margin-left: 6px; }
.demo-workspace-details[open] summary::after { content: '⌃'; }
.demo-workspace-details-panel {
  position: absolute; top: calc(100% + 8px); right: 0;
  width: min(280px, calc(100vw - 32px)); box-sizing: border-box;
  padding: 16px; border: 1px solid var(--bb-control-border); border-radius: 8px;
  background: var(--bb-surface); color: var(--bb-text); box-shadow: var(--shadow);
}
.demo-workspace-details-panel p { margin: 0 0 8px; }
.demo-workspace-banner a:focus-visible, .demo-workspace-details summary:focus-visible { outline: 2px solid var(--bb-accent); outline-offset: 2px; }
@media (max-width: 768px) {
  .demo-frame { --demo-banner-height: 88px; }
  .demo-frame .app-nav { height: auto; }
  .demo-frame #main { scroll-margin-top: calc(var(--demo-banner-height) + 80px); }
  .demo-workspace-banner { gap: 4px; padding: 8px 16px 4px; }
  .demo-workspace-identity { width: 100%; }
  .demo-workspace-desktop-meta { display: none; }
  .demo-workspace-actions { width: 100%; justify-content: space-between; gap: 2px; }
  .demo-workspace-actions a, .demo-workspace-details summary { min-height: 44px; }
  .demo-workspace-actions > a { padding: 0 4px; }
  .demo-workspace-details summary { padding: 0 2px; }
  .demo-workspace-details-panel { position: fixed; top: calc(var(--demo-banner-height) + 8px); right: 16px; }
}
.demo-short { display: none; }
/* Phones: one row (persona + short controls) so the banner does not take a fifth of the screen. */
@media (max-width: 560px) {
  /* One row at normal text size; still wraps (rather than overflowing) with enlarged text. */
  .demo-workspace-banner { gap: 0 8px; padding: 2px 12px; }
  .demo-workspace-identity { width: auto; flex: 1 1 6rem; min-width: 0; overflow: hidden; }
  .demo-workspace-identity strong { display: none; }
  .demo-workspace-persona { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; overflow-wrap: normal; }
  .demo-workspace-actions { width: auto; max-width: 100%; flex: 0 1 auto; flex-wrap: wrap; gap: 0; }
  .demo-long { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; }
  .demo-short { display: inline; }
  .demo-workspace-actions > a, .demo-workspace-details summary { padding: 0 8px; }
  .demo-workspace-back { border: 0; background: none; }
}
/* Touch: comfortable targets for the small text links that are not inside prose. */
@media (pointer: coarse) {
  .back-link, .today-section-link, .today-row-title, .today-pipeline a, .board-card-name {
    display: inline-flex; align-items: center; min-height: 44px;
  }
  .back-link { margin: 0; }
  /* Row checkboxes: a 44px hit area around the visible box. */
  .selection-cell { position: relative; min-width: 44px; }
  .selection-cell input[type="checkbox"] { width: 24px; height: 24px; margin: 10px; }
  .settings-row input[type="checkbox"], .hub-bar input[type="checkbox"] { width: 24px; height: 24px; }
}
.command-bar { position: relative; flex: 1 1 auto; min-width: 0; }
.command-bar form {
  display: flex;
  align-items: center;
  gap: 0.35rem;
}
.command-bar input {
  box-sizing: border-box;
  flex: 1 1 auto;
  min-width: 0;
  min-height: 36px;
  border: 1px solid var(--bb-control-border);
  border-radius: 8px;
  background: var(--surface);
  color: var(--ink);
  font: inherit;
  padding: 0.3rem 0.55rem;
}
.command-submit { box-sizing: border-box; min-height: 36px; flex: none; }
.command-submit-icon { display: none; }
.command-kbd {
  font-family: var(--font-mono);
  font-size: var(--bb-type-badge);
  color: var(--muted);
  border: 1px solid var(--line);
  border-radius: 6px;
  padding: 0.1rem 0.35rem;
}
.command-list {
  position: absolute;
  z-index: 40;
  top: calc(100% + 0.35rem);
  right: 0;
  width: min(22rem, 80vw);
  margin: 0;
  padding: 0.35rem;
  list-style: none;
  max-height: min(28rem, 60dvh);
  overflow: auto;
  overscroll-behavior: contain;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: var(--bb-panel);
  box-shadow: var(--shadow);
}
.command-list a {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.45rem 0.55rem;
  border-radius: 8px;
  color: var(--ink);
  text-decoration: none;
}
.command-list a:hover,
.command-list a:focus-visible { background: var(--paper-2); }
.command-list .hint { color: var(--muted); font-size: var(--bb-type-badge); }
.command-empty { padding: 0.55rem; color: var(--muted); font-size: 0.86rem; }
.candidate-frame { min-height: 100vh; background: var(--paper); color: var(--ink); }
.candidate-brand {
  background: var(--accent);
  color: var(--on-accent);
  padding: 1.4rem max(1.5rem, env(safe-area-inset-right)) 1.6rem max(1.5rem, env(safe-area-inset-left));
}
.candidate-kicker {
  margin: 0 0 0.35rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  font-size: var(--bb-type-badge);
  opacity: 0.85;
}
.candidate-word {
  color: inherit;
  font-family: var(--font-sans);
  font-size: 1.7rem;
  font-weight: 600;
  letter-spacing: -0.03em;
  text-decoration: none;
}
.candidate-sub { margin: 0.35rem 0 0; opacity: 0.9; }
.candidate-main { max-width: 40rem; margin: 0 auto; padding: 1.75rem 1.5rem 4rem; }
.candidate-main h1 {
  font-family: var(--font-sans);
  font-size: 1.45rem;
  letter-spacing: -0.03em;
  margin: 0 0 1rem;
}
.demo-disclaimer {
  margin: 0 0 1rem;
  padding: 0.55rem 0.75rem;
  border-radius: 8px;
  background: var(--warn-bg);
  color: var(--warn-fg);
  font-size: var(--bb-type-meta);
}
.landing {
  min-height: 100vh;
  background:
    radial-gradient(700px 320px at 100% 0%, var(--accent-soft) 0%, transparent 55%),
    var(--paper);
  color: var(--ink);
}
.landing-wrap { max-width: 960px; margin: 0 auto; padding: 4.5rem 1.5rem 4rem; }
.landing-kicker {
  margin: 0 0 0.6rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  font-size: var(--bb-type-badge);
  color: var(--muted);
}
.landing h1 {
  font-family: var(--font-sans);
  font-size: clamp(2.2rem, 6vw, 3.4rem);
  letter-spacing: -0.03em;
  line-height: 1.05;
  margin: 0 0 0.6rem;
  color: var(--accent);
}
.landing-lead { max-width: 36rem; color: var(--muted); margin: 0 0 1.5rem; }
.channel-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 0.75rem;
  margin: 0 0 2rem;
}
.role-grid { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.5rem; }
.role-grid button {
  width: 100%;
  text-align: left;
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  min-height: 48px;
  align-items: center;
}
.visually-hidden {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
@media (max-width: 768px) {
  /* Stacked layout: the content row takes any spare screen height, so a short page never stretches the nav row. */
  .app-shell { grid-template-columns: minmax(0, 1fr); grid-template-rows: auto 1fr; }
  .app-nav {
    position: sticky;
    top: 0;
    z-index: 30;
    height: auto;
    overflow: visible;
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    gap: 0.75rem;
    padding: max(0.7rem, env(safe-area-inset-top)) 1rem 0.7rem;
    border-right: 0;
    border-bottom: 1px solid var(--nav-line);
  }
  .app-nav-desktop { display: none; }
  .nav-drawer { display: block; }
  .nav-menu-btn { display: inline-flex; }
  .theme-switch-bar { display: flex; }
  .app-main { padding: 16px 16px max(32px, env(safe-area-inset-bottom)); }
  .page-head { align-items: flex-start; flex-direction: column; }
  .page-head-aside { position: relative; width: 100%; flex: none; }
  .page-head-aside .create-menu, .command-bar { position: static; }
  .page-head-aside .create-menu > summary { min-height: 44px; padding: 0.5rem 0.75rem; }
  .command-bar input { min-height: 44px; font-size: 16px; }
  .command-submit { width: 44px; min-height: 44px; padding: 0; }
  .command-submit-label, .command-kbd { display: none; }
  .command-submit-icon { display: block; width: 18px; height: 18px; }
  .command-list a, .create-menu-item { min-height: 44px; box-sizing: border-box; }
  .command-list { left: 0; right: auto; width: min(22rem, 100%); box-sizing: border-box; }
  .create-menu-panel { left: auto; right: 0; width: min(18rem, 100%); box-sizing: border-box; }
}
@media (prefers-reduced-motion: reduce) {
  .btn, .btn:hover { transition: none; transform: none; }
}
.brand-mark { font-family: var(--bb-font-body); gap: 8px; font-weight: 600; letter-spacing: -0.03em; }
.brand-image { display: block; width: 28px; height: 28px; object-fit: contain; flex: none; border-radius: 6px; background: var(--bb-brand-surface); }
.brand-mark .word { font-size: 18px; color: var(--bb-text); }
.app-nav .brand-mark { padding: 4px; }
.app-nav .nav-link[aria-current="page"] { box-shadow: inset 3px 0 var(--bb-accent); }
.row-list { list-style: none; margin: 0; padding: 0; }
.row-link { display: block; padding: 12px 0; min-height: 48px; box-sizing: border-box; border-bottom: 1px solid var(--bb-border); color: inherit; text-decoration: none; }
.row-link:hover { color: var(--bb-accent); background: var(--bb-surface-subtle); }
.row-link-title { display: block; font-size: var(--bb-type-body); font-weight: 600; }
.row-link-meta { display: block; margin-top: 4px; font-size: var(--bb-type-meta); color: var(--bb-text-muted); }
.field :is(input:not([type="checkbox"]):not([type="radio"]),select,textarea) { font-size: var(--bb-type-body); border-radius: var(--bb-control); }
.field textarea { min-height: 96px; resize: vertical; }
.field :is(input,select,textarea):disabled { background: var(--bb-disabled-bg); color: var(--bb-disabled); }
.field :is(input,select,textarea)[aria-invalid="true"] { border-color: var(--bb-danger); }
.field-help, .field-error { margin: 4px 0 0; font-size: var(--bb-type-meta); }
.field-help { color: var(--bb-text-muted); }
.field-error { color: var(--bb-danger); }
.chip { border-radius: var(--bb-badge); }
.pill:hover, .theme-switch button:hover { background: var(--bb-surface-subtle); }
.btn-ghost:active { background: var(--bb-accent-subtle); }
.table td, .table th { height: 40px; box-sizing: border-box; }
.table th { font-size: var(--bb-type-meta); }
.meta, .mono { font-size: var(--bb-type-meta); }
.notice-bad { color: var(--bb-danger); }
summary { cursor: pointer; }
:where(.app-main, .candidate-main) summary { min-height: 36px; box-sizing: border-box; }
[aria-busy="true"] { cursor: progress; }
@media(max-width:768px), (pointer:coarse) {
  :is(input:not([type="checkbox"]):not([type="radio"]):not([type="hidden"]),select,textarea) { font-size: 16px; min-height: 44px; }
  .btn, .btn-small, .pill, .theme-switch button, .nav-menu-btn { min-height: 44px; }
  .app-nav .theme-switch-bar { display: flex; }
  .app-nav-brand { flex-wrap: wrap; gap: 8px; }
  .app-nav-brand-actions { margin-left: auto; max-width: 100%; flex-shrink: 1; flex-wrap: wrap; gap: 8px; }
  .theme-switch button { padding: 4px 6px; }
  .theme-switch button.theme-to-dark, .theme-switch button.theme-to-light { width: 44px; padding: 0; }
}
/* Shared task composition, after the pilot migration. */
.workflow-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 24px; align-items: start; }
.workflow-grid > * { min-width: 0; }
.workflow-disclosure { margin: 16px 0 24px; padding: 12px 0; border-top: 1px solid var(--bb-border); border-bottom: 1px solid var(--bb-border); }
.workflow-disclosure > summary { cursor: pointer; font-weight: 600; min-height: 36px; display: list-item; align-content: center; }
.workflow-disclosure[open] > summary { margin-bottom: 16px; }
.workflow-disclosure .form-narrow { margin-top: 12px; }
.form-actions { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
.pool-board { margin: 16px 0 24px; }
.settings-navigation .tabs { margin-bottom: 16px; }
.settings-directory { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 24px; }
.settings-directory-link { display: block; padding: 16px 0; border-bottom: 1px solid var(--bb-border); min-width: 0; }
.settings-directory-link h2 { margin: 0 0 4px; font-size: var(--bb-type-section); color: var(--bb-accent); }
.settings-directory-link .sub { margin: 0; }
.settings-directory-link:hover h2 { text-decoration: underline; }
.hub-navigation nav[aria-label="Show"] { flex: 1 1 auto; }
.analytics-grid { max-width: 80rem; }
.analytics-stats { grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); margin: 0 0 20px; }
.stat-value { font-size: 1.6rem; line-height: 1.1; font-variant-numeric: tabular-nums; }
.stat-card .hint { font-size: var(--bb-type-badge); color: var(--muted); }
.board-card-pick { flex: 0 0 auto; width: 16px; height: 16px; margin: 2px 0 0; }
/* Public careers: the employer's brand page (V1 look). The org accent arrives as --careers-accent;
   display headings use Instrument Serif, scoped to this page only. Dark theme uses V1's ink palette. */
.careers-page { --careers-accent: var(--bb-accent); --careers-on-accent: var(--bb-on-accent); --careers-ink: var(--bb-text); --careers-muted: var(--bb-text-muted); --careers-canvas: var(--bb-bg); --careers-band: var(--bb-surface-subtle); --careers-panel: var(--bb-surface); --careers-line: var(--bb-border); --careers-display: 'Instrument Serif', var(--bb-font-body); background: var(--careers-canvas); color: var(--careers-ink); min-height: 100vh; }
.careers-hero { position: relative; overflow: hidden; isolation: isolate; display: grid; align-items: end; min-height: clamp(440px, 82vh, 800px); color: var(--bb-image-text); background: radial-gradient(circle at 72% 28%, color-mix(in srgb, var(--careers-accent) 35%, transparent), transparent 42%), linear-gradient(160deg, #0b1220 0%, #122033 45%, #0f3d3a 100%); }
.careers-hero > picture, .careers-hero > img { z-index: 0; }
.careers-hero-shade { position: absolute; inset: 0; z-index: 1; background: linear-gradient(180deg, rgba(7,16,24,0.2) 0%, rgba(7,16,24,0.55) 48%, rgba(7,16,24,0.94) 100%), linear-gradient(90deg, rgba(7,16,24,0.55), transparent 55%); }
.careers-hero-inner { position: relative; z-index: 2; width: min(1080px, calc(100% - 48px)); margin: 0 auto; padding: 88px 0 56px; display: grid; gap: 16px; animation: careersRise 0.9s cubic-bezier(0.2, 0.8, 0.2, 1) both; }
.careers-brand { display: inline-flex; align-items: center; gap: 12px; margin: 0; font-size: var(--bb-type-meta); font-weight: 600; letter-spacing: 0.14em; text-transform: uppercase; color: var(--careers-accent); }
.careers-brand img { width: 32px; height: 32px; border-radius: 6px; background: var(--bb-brand-surface); padding: 2px; box-sizing: border-box; }
.careers-hero h1 { margin: 0; max-width: 14ch; font-family: var(--careers-display); font-size: clamp(44px, 7vw, 86px); font-weight: 400; line-height: 0.95; letter-spacing: -0.03em; text-wrap: balance; }
.careers-subcopy { margin: 0; max-width: 38rem; font-size: 18px; line-height: 1.55; color: rgb(255 255 255 / 80%); }
.careers-cta { justify-self: start; display: inline-flex; align-items: center; min-height: 46px; margin-top: 8px; padding: 0 20px; border-radius: 999px; background: var(--careers-accent); color: var(--careers-on-accent); font-weight: 700; text-decoration: none; box-shadow: 0 16px 40px color-mix(in srgb, var(--careers-accent) 28%, transparent); transition: transform 160ms ease, box-shadow 160ms ease, filter 160ms ease; }
.careers-cta:hover { transform: translateY(-2px); filter: brightness(1.05); box-shadow: 0 20px 44px color-mix(in srgb, var(--careers-accent) 34%, transparent); }
.careers-section { border-top: 1px solid var(--careers-line); }
.careers-section-inner { width: min(1080px, calc(100% - 48px)); margin: 0 auto; padding: 64px 0; display: grid; gap: 20px; }
.careers-section h2 { margin: 0; font-family: var(--careers-display); font-size: clamp(30px, 3.4vw, 45px); font-weight: 400; line-height: 1.1; letter-spacing: -0.02em; }
.careers-lede { margin: 0; max-width: 42rem; color: var(--careers-muted); font-size: 17px; line-height: 1.6; }
.careers-values { display: grid; grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr)); gap: 16px; margin-top: 12px; }
.careers-value { padding: 20px 20px 22px; border-top: 2px solid var(--careers-accent); background: var(--careers-panel); animation: careersRise 0.8s cubic-bezier(0.2, 0.8, 0.2, 1) both; }
.careers-value:nth-child(2) { animation-delay: 80ms; }
.careers-value:nth-child(3) { animation-delay: 160ms; }
.careers-value h3 { margin: 0 0 8px; font-size: 17px; font-weight: 700; }
.careers-value p { margin: 0; color: var(--careers-muted); line-height: 1.5; font-size: 15px; }
.careers-roles-band { background: var(--careers-band); }
.careers-roles-head { display: grid; gap: 8px; }
.careers-muted { margin: 0; color: var(--careers-muted); }
.careers-filters { display: flex; flex-wrap: wrap; align-items: flex-end; gap: 12px; padding: 14px; border: 1px solid var(--careers-line); border-radius: 14px; background: var(--careers-panel); }
.careers-filters .field { margin: 0; flex: 1 1 12rem; }
.careers-clear { align-self: center; color: var(--careers-accent); }
.careers-group { display: grid; gap: 10px; margin-top: 8px; }
.careers-group-title { margin: 0; font-size: var(--bb-type-badge); font-weight: 650; letter-spacing: 0.08em; text-transform: uppercase; color: var(--careers-muted); }
.careers-roles { list-style: none; margin: 0; padding: 0; display: grid; gap: 10px; }
.careers-role { display: flex; align-items: center; gap: 16px; padding: 15px 18px; border: 1px solid var(--careers-line); border-radius: 8px; background: var(--careers-panel); transition: border-color 0.15s ease, background-color 0.15s ease; }
.careers-role:hover { border-color: color-mix(in srgb, var(--careers-accent) 45%, var(--careers-line)); }
.careers-role-link { flex: 1 1 auto; min-width: 0; display: grid; gap: 3px; color: var(--careers-ink); text-decoration: none; }
.careers-role-title { font-weight: 650; font-size: 17px; line-height: 1.25; overflow-wrap: anywhere; }
.careers-role-link:hover .careers-role-title { text-decoration: underline; }
.careers-role-meta { color: var(--careers-muted); font-size: var(--bb-type-meta); margin: 0; }
.careers-page .careers-apply { flex: 0 0 auto; background: var(--careers-accent); border-color: transparent; color: var(--careers-on-accent); }
.careers-page .careers-apply:hover { background: var(--careers-accent); filter: brightness(1.05); }
.careers-page a:focus-visible { outline: 2px solid var(--careers-accent); outline-offset: 2px; }
.careers-footer { width: min(1080px, calc(100% - 48px)); margin: 0 auto; padding: 24px 0 32px; box-sizing: border-box; display: flex; flex-wrap: wrap; justify-content: space-between; gap: 12px; border-top: 1px solid var(--careers-line); color: var(--careers-muted); font-size: var(--bb-type-meta); }
.careers-about { margin: 12px 0 24px; padding: 12px 16px; border: 1px solid var(--bb-border); border-radius: 8px; background: var(--bb-surface); }
.careers-about > summary { font-weight: 600; cursor: pointer; }
.careers-description { line-height: 1.6; }
.careers-description h3 { font-size: var(--bb-type-section); margin: 16px 0 4px; }
.careers-description ul { margin: 4px 0 12px; padding-left: 1.25rem; }
@keyframes careersRise { from { opacity: 0; transform: translateY(14px); } to { opacity: 1; transform: none; } }
@media (prefers-reduced-motion: reduce) { .careers-hero-inner, .careers-value { animation: none; } .careers-cta:hover { transform: none; } }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) .careers-page { --careers-ink: #e8eef5; --careers-muted: #9bb0c3; --careers-canvas: #071018; --careers-band: #050c12; --careers-panel: rgb(255 255 255 / 4%); --careers-line: rgb(255 255 255 / 10%); } }
:root[data-theme="dark"] .careers-page { --careers-ink: #e8eef5; --careers-muted: #9bb0c3; --careers-canvas: #071018; --careers-band: #050c12; --careers-panel: rgb(255 255 255 / 4%); --careers-line: rgb(255 255 255 / 10%); }
@media (max-width: 600px) {
  .careers-hero { min-height: clamp(420px, 78vh, 640px); }
  .careers-hero-inner, .careers-section-inner, .careers-footer { width: calc(100% - 32px); }
  .careers-hero-inner { padding: 64px 0 40px; }
  .careers-section-inner { padding: 40px 0; }
  .careers-role { flex-wrap: wrap; }
  .careers-page .careers-apply { width: 100%; justify-content: center; min-height: 44px; }
}
.candidate-brand { background: var(--bb-surface); color: var(--bb-text); border-bottom: 1px solid var(--bb-border); padding: 16px max(16px, env(safe-area-inset-left)); }
.candidate-word { font-size: var(--bb-type-section); color: var(--bb-accent); }
.candidate-main { padding: 24px 24px 40px; min-width: 0; overflow-wrap: anywhere; }
.candidate-main h1 { font-size: var(--bb-type-page); }
.candidate-main h2 { font-size: var(--bb-type-section); }
.candidate-main form > section { padding-top: 16px; margin-top: 16px; border-top: 1px solid var(--bb-border); }
.candidate-main :is(img,video,iframe) { max-width: 100%; }
.candidate-main table { display: block; max-width: 100%; overflow-x: auto; }
.candidate-success { padding: 16px; border-left: 3px solid var(--bb-success); background: var(--bb-success-bg); }
.login-brand { margin-bottom: 24px; }
.landing-brand { margin-bottom: 24px; }
.landing-brand .brand-image { width: 64px; height: 64px; }
.landing-brand .word { font-size: var(--bb-type-page); }
.app-main :is(h2,h3) { scroll-margin-top: 120px; }
.app-main, .candidate-main { overflow-wrap: anywhere; }
@media (max-width: 820px) { .workflow-grid { grid-template-columns: minmax(0, 1fr); } }
@media (max-width: 600px) {
  .settings-directory { grid-template-columns: minmax(0, 1fr); }
  .candidate-main { padding: 24px 16px 40px; }
  .workflow-disclosure > summary { min-height: 44px; }
}
}
`
