export const labCss = `
@layer bb-surfaces {
@scope (.lab-root) {
:scope { font: 14px/1.45 var(--bb-font-body); color: var(--bb-text); }
* { box-sizing: border-box; }
h1, h2, h3, p { margin: 0; }
h1 { font-size: 24px; line-height: 1.25; font-weight: 600; }
h2, h3 { font-size: 16px; line-height: 1.35; font-weight: 600; }
a { color: var(--bb-accent); text-underline-offset: 3px; }
button, input, select, textarea { font: inherit; }
button, summary, a { -webkit-tap-highlight-color: transparent; }
button { cursor: pointer; }
button:disabled { cursor: not-allowed; color: var(--bb-disabled); background: var(--bb-disabled-bg); }
:where(button, a, input, select, textarea, summary, pre):focus-visible { outline: 2px solid var(--bb-accent); outline-offset: 2px; }
.lab-header { display: flex; align-items: center; flex-wrap: wrap; gap: 24px; padding: 16px 24px; border-bottom: 1px solid var(--bb-border); background: var(--bb-surface); }
.lab-brand-group { display: flex; align-items: center; gap: 8px; }
.lab-header .brand-mark { font: 600 18px/1.25 var(--bb-font-body); gap: 8px; }
.lab-header nav { display: flex; gap: 24px; margin-right: auto; }
.lab-header nav a { text-decoration: none; font-weight: 500; color: var(--bb-text); }
.lab-header .theme-switch-bar { display: flex; margin-left: auto; }
.lab-entry { max-width: 1120px; margin: auto; padding: 32px 24px 0; }
.lab-entry-heading { display: grid; gap: 8px; margin-bottom: 24px; }
.lab-entry-heading > p:last-child { max-width: 75ch; color: var(--bb-text-muted); }
.lab-eyebrow, .lab-note { font-size: 13px; line-height: 1.4; color: var(--bb-text-muted); }
.lab-eyebrow { font-weight: 500; }
.lab-card-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px; margin-bottom: 24px; }
.lab-card { display: flex; flex-direction: column; gap: 12px; padding: 16px; border: 1px solid var(--bb-control-border); border-radius: 8px; background: var(--bb-surface); color: var(--bb-text); text-decoration: none; }
.lab-card:hover { background: var(--bb-surface-subtle); border-color: var(--bb-accent); }
.lab-card p { color: var(--bb-text-muted); }
.lab-card-cta { color: var(--bb-accent); font-weight: 500; margin-top: auto; }
.lab-public-entry { padding-top: 40px; }
.lab-public-heading { display: block; position: relative; padding-left: 200px; margin-bottom: 32px; }
.lab-public-heading > div { min-width: 0; }
.lab-public-mark { position: absolute; inset: 0 auto auto 0; width: 168px; height: auto; aspect-ratio: 1; border-radius: 20px; background: #fff; }
.lab-public-heading h1 { font-size: 48px; line-height: 1.2; letter-spacing: -.025em; margin: 0 0 16px; }
.lab-public-heading h1 > span { display: inline; }
.lab-headline-accent { color: var(--bb-accent); }
.lab-nowrap { white-space: nowrap; }
.lab-public-actions { margin: 16px 0 0; }
.lab-public-actions .lab-primary { min-height: 44px; padding-inline: 18px; }
.lab-public-intro { color: var(--bb-text); font-size: 16px; margin-bottom: 4px; }
.lab-card-interface { display: flex; flex-wrap: wrap; align-items: baseline; gap: 4px 8px; color: var(--bb-accent); font-size: 13px; font-weight: 600; }
.lab-card-audience { color: var(--bb-text-muted); font-weight: 500; }
.lab-public-entry .lab-card { padding: 20px; gap: 10px; border-color: var(--bb-border); }
.lab-public-entry .lab-card:hover { border-color: var(--bb-accent); }
.lab-public-entry .lab-card h2 { font-size: 18px; }
.lab-preview { display: grid; gap: 6px; margin: auto 0 4px; padding: 12px; border: 1px solid var(--bb-border); border-radius: 6px; background: var(--bb-surface-subtle); }
.lab-preview-label { font-size: 12px; color: var(--bb-text-muted); }
.lab-preview code { font: 12px/1.5 var(--bb-font-code); overflow-wrap: anywhere; }
.lab-preview-outcome { color: var(--bb-accent); }
.lab-preview-ui code:first-of-type { background: var(--bb-accent-subtle); border-left: 2px solid var(--bb-accent); padding: 4px 6px; }
.lab-public-entry .lab-card-cta { margin-top: 4px; }

.surface-tabs { display: flex; flex-wrap: wrap; gap: 4px; }
.surface-tabs { width: fit-content; padding: 4px; border: 1px solid var(--bb-border); border-radius: 8px; background: var(--bb-surface); }
.surface-tabs button { display: inline-flex; align-items: center; min-height: 36px; padding: 6px 12px; border: 0; background: transparent; border-radius: 6px; text-decoration: none; color: var(--bb-text-muted); }
.surface-tabs button:hover { background: var(--bb-surface-subtle); color: var(--bb-text); }
.surface-tabs button.selected { background: var(--bb-accent-subtle); color: var(--bb-text); box-shadow: inset 0 -2px var(--bb-accent); }
.surface-tabs button:disabled, .step-link[aria-disabled=true] { color: var(--bb-disabled); cursor: not-allowed; }
.lab-personas { border-top: 1px solid var(--bb-border); padding-top: 24px; }
.lab-personas > .lab-note { margin-top: 8px; }
.persona-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; margin: 16px 0; }
.persona-grid-ui { grid-template-columns: repeat(2,minmax(0,1fr)); }
.persona-grid form { min-width: 0; }
.persona { display: flex; align-items: center; gap: 12px; width: 100%; height: 100%; text-align: left; padding: 16px; background: var(--bb-surface); color: var(--bb-text); border: 1px solid var(--bb-control-border); border-radius: 8px; }
.persona:hover { background: var(--bb-surface-subtle); border-color: var(--bb-accent); }
.persona-avatar { display: grid; place-items: center; flex: none; width: 36px; height: 36px; border-radius: 50%; font-size: 12px; background: var(--bb-accent-subtle); color: var(--bb-accent); }
.persona > span:nth-child(2) { min-width: 0; overflow-wrap: anywhere; }
.persona strong, .persona > span > span, .persona small { display: block; }
.persona > span > span, .persona small { color: var(--bb-text-muted); font-size: 13px; margin-top: 4px; }
.persona-go { color: var(--bb-accent); margin-left: auto; }
.lab-footer { display: flex; justify-content: center; flex-wrap: wrap; gap: 16px; border-top: 1px solid var(--bb-border); padding: 24px; margin-top: 24px; color: var(--bb-text-muted); font-size: 13px; }
.lab-workspace { max-width: 1720px; margin: auto; padding: 24px; }
.workbench-top { display: flex; flex-wrap: wrap; align-items: center; gap: 20px; margin-bottom: 12px; }
.workbench-top > div { display: grid; gap: 4px; }
.bench-grid { display: grid; grid-template-columns: 224px minmax(0, 1fr) 260px; gap: 16px; align-items: start; }
.story-panel, .record-panel, .execution-panel { min-width: 0; }
.story-panel h2 { margin: 8px 0; }
.story-panel > p { color: var(--bb-text-muted); font-size: 13px; }
.story-steps { display: grid; gap: 4px; padding: 0; margin: 0 0 16px; list-style: none; }
.story-step { display: flex; gap: 8px; width: 100%; text-align: left; color: var(--bb-text); background: transparent; border: 1px solid transparent; border-radius: 6px; padding: 8px; min-height: 44px; }
.story-step:hover { background: var(--bb-surface-subtle); }
.story-step.selected { background: var(--bb-accent-subtle); border-color: var(--bb-accent); }
.story-step strong { display: block; font-weight: 500; }
.story-step small { display: block; font-size: 13px; color: var(--bb-text-muted); margin-top: 4px; }
.step-index { flex: none; color: var(--bb-text-muted); font-size: 12px; padding-top: 2px; }
.step-index.done { color: var(--bb-success); }
.story-step .permission-hint { color: var(--bb-warning); }
.step-link { display: inline-block; font-size: 13px; margin: 4px 8px 8px 32px; }
.execution-panel { padding: 16px; border: 1px solid var(--bb-border); border-radius: 8px; background: var(--bb-surface); }
.lab-unavailable { display: grid; gap: 12px; max-width: 75ch; }
.execution-panel input, .execution-panel select, .execution-panel textarea, .operation-selector input, .operation-selector select { display: block; width: 100%; min-width: 0; min-height: 36px; border: 1px solid var(--bb-control-border); border-radius: 6px; background: var(--bb-surface); color: var(--bb-text); padding: 6px 8px; }
.execution-panel textarea { font: 13px/1.5 var(--bb-font-code); resize: vertical; }
.bench-label { display: block; font-size: 13px; font-weight: 500; margin: 12px 0 4px; }
.bench-label:first-child { margin-top: 0; }
.operation-selector { margin-bottom: 12px; }
.operation-selector summary { overflow-wrap: anywhere; }
.operation-selector summary code { font: inherit; font-weight: 600; }
@media(min-width:901px) { .operation-selector > summary { display: none; } }
.operation-heading { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; margin: 12px 0 8px; }
.operation-heading code, .result-request { font: 13px/1.5 var(--bb-font-code); overflow-wrap: anywhere; }
.method { border: 1px solid var(--bb-border); border-radius: 4px; padding: 2px 6px; font-size: 12px; background: var(--bb-surface-subtle); }
.operation-description { font-size: 13px; color: var(--bb-text-muted); }
.argument-fields { display: grid; grid-template-columns: repeat(2,minmax(0,1fr)); gap: 12px; margin: 12px 0; }
.argument-field { min-width: 0; }
.argument-field:has(textarea) { grid-column: 1/-1; }
.argument-field > span { display: block; font-size: 13px; font-weight: 500; margin-bottom: 4px; }
.argument-field small { display: block; font-size: 13px; color: var(--bb-text-muted); font-weight: 400; overflow-wrap: anywhere; }
.argument-field > span > strong { color: var(--bb-danger); }
.run-row { display: flex; align-items: center; flex-wrap: wrap; gap: 12px; margin: 12px 0; }
.run-row > span { font-size: 13px; color: var(--bb-text-muted); }
.lab-primary, .lab-secondary, .text-button { display: inline-flex; align-items: center; justify-content: center; gap: 8px; min-height: 36px; border: 1px solid var(--bb-control-border); border-radius: 6px; padding: 6px 12px; font: 500 14px/1.45 var(--bb-font-body); text-decoration: none; }
.lab-primary { background: var(--bb-accent); color: var(--bb-on-accent); border-color: var(--bb-accent); }
.lab-primary:hover { background: var(--bb-accent-hover); }
.lab-primary:active { background: var(--bb-accent-pressed); }
.lab-primary:disabled, .lab-primary[aria-disabled=true] { background: var(--bb-disabled-bg); color: var(--bb-disabled); border-color: var(--bb-control-border); }
.lab-secondary, .text-button { background: var(--bb-surface); color: var(--bb-text); }
.lab-secondary:hover, .text-button:hover { background: var(--bb-surface-subtle); }
.text-button { border-color: transparent; color: var(--bb-accent); padding-inline: 8px; }
details { min-width: 0; }
summary { min-height: 36px; padding: 6px 0; cursor: pointer; font-weight: 500; }
details > p, details > details, details > a { margin-top: 8px; }
pre { max-width: 100%; overflow: auto; font: 13px/1.5 var(--bb-font-code); background: var(--bb-surface-subtle); border: 1px solid var(--bb-border); border-radius: 6px; padding: 12px; margin: 8px 0; tab-size: 2; }
.scope-inspector { margin-top: 4px; }
.experiment-about { margin-top: 4px; }
.experiment-about dl { margin: 12px 0; }
.experiment-about dl > div + div { margin-top: 12px; }
.experiment-about dt { font-weight: 500; }
.experiment-about dd { margin: 4px 0 0; color: var(--bb-text-muted); font-size: 13px; }
.lab-error { border: 1px solid var(--bb-danger); color: var(--bb-danger); background: var(--bb-danger-bg); border-radius: 6px; padding: 12px; margin: 12px 0; font-size: 14px; overflow-wrap: anywhere; }
.result-panel { border-top: 1px solid var(--bb-border); padding-top: 16px; margin-top: 16px; scroll-margin-top: calc(var(--demo-banner-height, 48px) + 16px); }
.result-panel > h2 { margin-bottom: 8px; }
.result-heading { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin: 8px 0; font-size: 13px; }
.result-status { border-radius: 4px; padding: 2px 6px; font-weight: 500; }
.result-status.good { color: var(--bb-success); background: var(--bb-success-bg); }
.result-status.bad { color: var(--bb-danger); background: var(--bb-danger-bg); }
.result-empty { margin-top: 16px; padding-top: 16px; border-top: 1px solid var(--bb-border); color: var(--bb-text-muted); font-size: 13px; }
.result-panel pre { max-height: 560px; }
.record-panel { border: 1px solid var(--bb-border); border-radius: 8px; padding: 12px; background: var(--bb-surface); }
.record-panel > details > summary { font-size: 16px; }
.record-panel p, .record-panel small { font-size: 13px; color: var(--bb-text-muted); }
.record-links { display: grid; gap: 4px; margin: 8px 0; }
.record-link { display: flex; justify-content: space-between; align-items: center; gap: 8px; min-width: 0; width: 100%; text-align: left; border: 1px solid var(--bb-control-border); border-radius: 6px; background: var(--bb-surface); color: var(--bb-text); padding: 8px; }
.record-link span { overflow-wrap: anywhere; }
.record-link-row { display: flex; align-items: center; gap: 8px; min-width: 0; }
.record-link-row .record-link { flex: 1; }
.record-json-link { flex: none; font-size: 13px; }
.record-link.selected { border-color: var(--bb-accent); background: var(--bb-accent-subtle); }
.record-json { max-height: 400px; }
.how-link { display: block; width: fit-content; font-size: 13px; margin: 8px 0; }
.ui-launch { display: grid; gap: 12px; }
.ui-link-grid { display: flex; flex-wrap: wrap; gap: 12px; }
.terminal-suggestions, .command-history { display: grid; gap: 4px; margin-top: 12px; }
.terminal-suggestions button, .command-history button { background: var(--bb-surface-subtle); border: 1px solid var(--bb-control-border); border-radius: 6px; color: var(--bb-text); padding: 8px; text-align: left; font: 13px/1.5 var(--bb-font-code); overflow-wrap: anywhere; }
.draft-controls { display: flex; align-items: start; flex-wrap: wrap; gap: 8px; font-size: 13px; margin: 8px 0; }
.draft-controls > details { flex: 1; }
.draft-controls label { display: flex; align-items: start; gap: 8px; margin-top: 8px; }
.execution-panel .draft-controls input[type=checkbox] { width: 18px; min-height: 18px; flex: none; margin: 2px 0; }
.draft-controls p { color: var(--bb-text-muted); margin: 8px 0; }
.draft-recovery { box-sizing: border-box; max-width: min(540px,calc(100vw - 32px)); border: 1px solid var(--bb-control-border); border-radius: 8px; padding: 24px; background: var(--bb-surface); color: var(--bb-text); }
.draft-recovery::backdrop { background: #0008; }
.draft-recovery h2 { font-size: 16px; margin-top: 0; }
.draft-recovery button { margin: 4px; }
.draft-recovery p { font-size: 14px; margin: 12px 0; }
.execution-panel > [role=status]:empty { display: none; }
@media(max-width:1200px) {
 .bench-grid { grid-template-columns: 224px minmax(0,1fr); }
 .record-panel { grid-column: 2; }
}
@media(max-width:900px) {
 .lab-public-heading { display: grid; padding-left: 0; gap: 16px; }
 .lab-public-mark { position: static; width: 64px; height: 64px; border-radius: 14px; }
 .persona-grid { grid-template-columns: repeat(2,minmax(0,1fr)); }
 .lab-card-grid { grid-template-columns: repeat(2,minmax(0,1fr)); }
 .bench-grid { grid-template-columns: minmax(0,1fr); }
 .story-panel, .record-panel { grid-column: 1; }
 .story-panel { order: 1; }
 .execution-panel { order: 2; }
 .record-panel { order: 3; }
}
/* Phones: the hero button covers careers, so the header keeps one row. */
@media(max-width:480px) { .lab-header .lab-nav-careers { display: none; } }
/* Phones: the public entry is a 2x2 of tappable interfaces — name, who it is for, one action. */
@media(max-width:600px) {
 .lab-public-heading .lab-note { display: none; }
 /* Mark sits on the headline's row; intro and button run full width beneath. */
 .lab-public-entry .lab-public-heading { grid-template-columns: 56px minmax(0, 1fr); column-gap: 14px; row-gap: 0; align-items: center; }
 .lab-public-entry .lab-public-heading > div { display: contents; }
 .lab-public-entry .lab-public-mark { grid-column: 1; grid-row: 1; width: 56px; height: 56px; border-radius: 12px; }
 .lab-public-entry .lab-public-heading h1 { grid-column: 2; grid-row: 1; margin: 0; font-size: 30px; line-height: 1.2; }
 .lab-public-entry .lab-public-heading > div > :not(h1) { grid-column: 1 / -1; }
 .lab-public-entry .lab-public-intro { margin-top: 16px; }
 .lab-public-entry .lab-card-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
 .lab-public-entry .lab-card { min-height: 128px; padding: 16px; gap: 6px; }
 .lab-public-entry .lab-card h2, .lab-public-entry .lab-card p, .lab-public-entry .lab-preview { display: none; }
 .lab-public-entry .lab-card-interface { flex-direction: column; gap: 4px; font-size: 22px; font-weight: 650; letter-spacing: -0.01em; }
 .lab-public-entry .lab-card-audience { font-size: 14px; font-weight: 500; letter-spacing: 0; }
 .lab-public-entry .lab-card-cta { margin-top: auto; font-size: 15px; white-space: nowrap; }
}
@media(max-width:380px) {
 .lab-public-entry .lab-card-grid { gap: 10px; }
 .lab-public-entry .lab-card { padding: 14px 12px; }
 .lab-public-entry .lab-card-audience, .lab-public-entry .lab-card-cta { font-size: 14px; }
}
@media(max-width:600px),(pointer:coarse) {
 .lab-header { padding: 12px 16px; gap: 12px; }
 .lab-header nav { gap: 16px; margin-right: 0; }
 .lab-entry, .lab-workspace { padding: 16px; }
 .lab-public-entry { padding-top: 24px; }
 .lab-public-heading { margin-bottom: 24px; }
 .lab-public-mark { width: 64px; height: 64px; border-radius: 14px; }
 .lab-public-heading h1 { font-size: 32px; }
 .lab-public-entry .lab-card { padding: 16px; }
 .lab-preview { gap: 4px; }
 .lab-header .theme-switch-bar { margin-left: auto; }
 .persona-grid, .persona-grid-ui, .lab-card-grid { grid-template-columns: minmax(0,1fr); }
 .persona { padding: 12px; }
 .argument-fields { grid-template-columns: minmax(0,1fr); }
 .execution-panel input, .execution-panel select, .execution-panel textarea, .operation-selector input, .operation-selector select { font-size: 16px; min-height: 44px; }
 .lab-primary, .lab-secondary, .text-button, summary, .surface-tabs button { min-height: 44px; }
 .surface-tabs button { padding-inline: 10px; }
 .execution-panel { padding: 12px; }
}
}
}
`
