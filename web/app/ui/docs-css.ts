export const docsCss = `
@layer bb-surfaces {
@scope (.docs-root) {
:scope { --docs-header-height: 72px; }
.docs-header {
  position: sticky; top: 0; z-index: 30;
  display: flex; align-items: center; flex-wrap: wrap; gap: 16px 24px;
  min-height: 64px; box-sizing: border-box; padding: 12px 24px;
  border-bottom: 1px solid var(--bb-border); background: var(--bb-surface);
}
.docs-header nav { display: flex; align-items: center; gap: 8px; }
.docs-header nav a { display: inline-flex; align-items: center; min-height: 36px; padding: 0 12px; border-radius: var(--bb-control); font-size: var(--bb-type-body); }
.docs-header nav a[aria-current] { background: var(--bb-accent-subtle); color: var(--bb-text); font-weight: 600; }
.docs-header nav a:hover { background: var(--bb-surface-subtle); }
.docs-header .theme-switch { display: flex; margin-left: auto; }
.docs-layout { display: grid; grid-template-columns: 232px minmax(0, 1fr) 200px; gap: 24px; max-width: 1440px; margin: 0 auto; padding: 24px; box-sizing: border-box; }
.docs-layout[data-outline="false"] { grid-template-columns: 232px minmax(0, 1fr); }
.docs-sidebar, .docs-outline {
  position: sticky; top: calc(var(--docs-header-height) + 24px); align-self: start;
  max-height: calc(100dvh - var(--docs-header-height) - 48px); overflow: auto; overscroll-behavior: contain;
  min-width: 0; box-sizing: border-box;
}
.docs-sidebar { border-right: 1px solid var(--bb-border); padding-right: 16px; }
.docs-sidebar-label { font-size: var(--bb-type-section); font-weight: 600; margin: 0 0 16px; }
.docs-search-label { display: flex; justify-content: space-between; gap: 8px; font-size: var(--bb-type-meta); color: var(--bb-text-muted); margin-bottom: 8px; }
.docs-search-label kbd { font: inherit; border: 1px solid var(--bb-border); border-radius: var(--bb-badge); padding: 0 6px; }
.docs-sidebar input { box-sizing: border-box; width: 100%; padding: 6px 12px; min-height: 36px; border: 1px solid var(--bb-control-border); background: var(--bb-surface); border-radius: var(--bb-control); color: var(--bb-text); font: 400 var(--bb-type-body)/1.45 var(--bb-font-body); }
.docs-group { font-size: var(--bb-type-meta); font-weight: 600; color: var(--bb-text-muted); margin: 24px 0 8px; }
.docs-sidebar nav a { display: block; text-decoration: none; font-size: var(--bb-type-body); color: var(--bb-text); padding: 8px 12px; border-radius: var(--bb-control); margin: 4px 0; overflow-wrap: anywhere; }
.docs-sidebar nav a[aria-current] { background: var(--bb-accent-subtle); font-weight: 600; box-shadow: inset 3px 0 var(--bb-accent); }
.docs-sidebar nav a:hover { background: var(--bb-surface-subtle); }
.docs-topics-mobile { display: none; }
.docs-search-empty { font-size: var(--bb-type-body); color: var(--bb-text-muted); margin: 16px 0; }
.docs-main { min-width: 0; padding-bottom: 8px; }
.docs-breadcrumb { font-size: var(--bb-type-meta); color: var(--bb-text-muted); margin: 0 0 16px; overflow-wrap: anywhere; }
.docs-breadcrumb a:hover { text-decoration: underline; }
.docs-breadcrumb span { padding: 0 8px; }
.docs-prose { font-size: var(--bb-type-prose); line-height: 1.65; overflow-wrap: anywhere; color: var(--bb-text); }
.docs-prose h1 { font: 600 var(--bb-type-page)/1.25 var(--bb-font-body); margin: 0 0 16px; color: var(--bb-text); }
.docs-prose h2 { font: 600 var(--bb-type-section)/1.35 var(--bb-font-body); margin: 32px 0 12px; }
.docs-prose h3, .docs-prose h4 { font: 600 var(--bb-type-section)/1.35 var(--bb-font-body); margin: 24px 0 12px; }
[id] { scroll-margin-top: calc(var(--docs-header-height) + 16px); }
.docs-prose p, .docs-prose ul, .docs-prose ol, .docs-prose blockquote { max-width: 75ch; }
.docs-prose p { margin: 16px 0; }
.docs-prose strong { font-weight: 600; }
.docs-prose ul, .docs-prose ol { padding-left: 24px; }
.docs-prose li { margin: 8px 0; }
.docs-prose a { color: var(--bb-accent); text-decoration: underline; text-underline-offset: 3px; }
.docs-prose p > a:only-child { display: inline-block; padding: 4px 0; font-size: var(--bb-type-body); font-weight: 500; }
.docs-prose :not(pre) > code { font: var(--bb-type-code)/1.5 var(--bb-font-code); background: var(--bb-surface-subtle); border: 1px solid var(--bb-border); border-radius: var(--bb-badge); padding: 2px 4px; }
.docs-code { border: 1px solid var(--bb-control-border); border-radius: var(--bb-panel); margin: 24px 0; background: var(--bb-surface); min-width: 0; }
.docs-code-toolbar { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; padding: 4px 12px; border-bottom: 1px solid var(--bb-border); color: var(--bb-text-muted); font: var(--bb-type-meta)/1.4 var(--bb-font-body); }
.docs-code button { border: 1px solid transparent; background: transparent; color: var(--bb-accent); font: 500 var(--bb-type-meta)/1.4 var(--bb-font-body); min-height: 36px; padding: 4px 8px; border-radius: var(--bb-control); cursor: pointer; }
.docs-code button:hover { background: var(--bb-surface-subtle); }
.docs-code pre { margin: 0; padding: 16px; overflow: auto; max-height: 60dvh; overscroll-behavior: contain; font: var(--bb-type-code)/1.5 var(--bb-font-code); tab-size: 2; border-radius: 0 0 var(--bb-panel) var(--bb-panel); }
.docs-code pre:focus-visible, .docs-table:focus-visible { outline-offset: 2px; }
.docs-outline { border-left: 1px solid var(--bb-border); padding-left: 16px; font-size: var(--bb-type-meta); }
.docs-outline > p { font-size: var(--bb-type-body); font-weight: 600; margin: 0 0 12px; }
.docs-outline a { display: block; line-height: 1.4; color: var(--bb-text-muted); text-decoration: none; padding: 8px 0; overflow-wrap: anywhere; }
.docs-outline a:hover { color: var(--bb-accent); text-decoration: underline; }
.docs-outline .docs-lab-link { border-top: 1px solid var(--bb-border); padding-top: 16px; margin-top: 16px; color: var(--bb-accent); }
.docs-diagram { display: flex; flex-direction: column; align-items: center; gap: 8px; padding: 16px; background: var(--bb-surface); border: 1px solid var(--bb-border); border-radius: var(--bb-panel); font: var(--bb-type-body)/1.45 var(--bb-font-body); margin: 24px 0; text-align: center; }
.docs-diagram div { padding: 8px 12px; border: 1px solid var(--bb-control-border); border-radius: var(--bb-control); background: var(--bb-accent-subtle); max-width: 100%; box-sizing: border-box; overflow-wrap: anywhere; }
.docs-diagram span { color: var(--bb-text-muted); font-size: var(--bb-type-meta); }
.docs-diagram section { display: grid; gap: 8px; min-width: 0; max-width: 100%; }
.docs-diagram.flow { flex-direction: row; flex-wrap: wrap; justify-content: center; }
.docs-pagination { display: flex; justify-content: space-between; flex-wrap: wrap; gap: 16px; margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--bb-border); font-size: var(--bb-type-body); }
.docs-pagination a { padding: 4px 0; overflow-wrap: anywhere; color: var(--bb-accent); }
.docs-pagination a:hover { text-decoration: underline; }
.docs-footnote { font-size: var(--bb-type-meta); line-height: 1.4; color: var(--bb-text-muted); margin-top: 24px; }
.docs-table { overflow: auto; max-width: 100%; margin: 24px 0; overscroll-behavior: contain; }
.docs-prose table { width: 100%; min-width: 32rem; border-collapse: collapse; font-size: var(--bb-type-body); }
.docs-prose td, .docs-prose th { text-align: left; padding: 12px; border-bottom: 1px solid var(--bb-border); }
.docs-prose th { background: var(--bb-surface-subtle); font-weight: 600; }
@media (max-width: 1200px) {
  .docs-layout { grid-template-columns: 232px minmax(0, 1fr); }
  .docs-outline { display: none; }
}
@media (max-width: 900px) {
  :scope { --docs-header-height: 128px; }
  .docs-header { gap: 8px 16px; padding: 8px 16px; }
  .docs-header nav a, .docs-header .theme-switch button { min-height: 44px; }
  .docs-layout { display: block; padding: 16px; }
  .docs-sidebar { position: relative; top: auto; max-height: none; overflow: visible; border: 0; padding: 0 0 16px; }
  .docs-sidebar-label { display: none; }
  .docs-topics-desktop { display: none; }
  .docs-topics-mobile { display: block; margin-top: 12px; }
  .docs-topics-mobile > summary { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 4px 12px; min-height: 44px; padding: 8px 12px; box-sizing: border-box; border: 1px solid var(--bb-control-border); border-radius: var(--bb-control); background: var(--bb-surface); font-size: var(--bb-type-body); cursor: pointer; list-style: none; }
  .docs-topics-mobile > summary::marker { content: ''; }
  .docs-topics-mobile > summary::-webkit-details-marker { display: none; }
  .docs-topics-mobile > summary::after { content: '⌄'; margin-left: auto; }
  .docs-topics-mobile[open] > summary::after { content: '⌃'; }
  .docs-topic-context { color: var(--bb-text-muted); font-size: var(--bb-type-meta); overflow-wrap: anywhere; }
  .docs-topic-panel { position: absolute; top: 100%; left: 0; right: 0; z-index: 20; box-sizing: border-box; max-height: 60dvh; overflow: auto; overscroll-behavior: contain; padding: 8px 16px; border: 1px solid var(--bb-control-border); border-radius: var(--bb-panel); background: var(--bb-surface); box-shadow: var(--bb-shadow); }
  .docs-group { margin-top: 16px; }
  .docs-sidebar input { min-height: 44px; font-size: 16px; }
  .docs-sidebar nav a, .docs-pagination a, .docs-prose p > a:only-child { min-height: 44px; box-sizing: border-box; }
  .docs-code button { min-height: 44px; }
}
@media (pointer: coarse) {
  .docs-sidebar input { min-height: 44px; font-size: 16px; }
  .docs-code button, .docs-header nav a { min-height: 44px; }
}
}
}
`
