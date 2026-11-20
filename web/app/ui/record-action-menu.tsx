import type { Handle, RemixNode } from 'remix/component'
import { RecordActionBehavior } from './public/record-action-menu.tsx'

export function RecordActionMenu(
  handle: Handle<{ label: string; children?: RemixNode; initiallyOpen?: boolean; wide?: boolean }>,
) {
  return () => (
    <details class="record-action-menu" open={handle.props.initiallyOpen}>
      <summary class="btn btn-ghost">
        {handle.props.label} <span aria-hidden="true">⌄</span>
      </summary>
      <div class={handle.props.wide ? 'record-action-panel record-action-panel-wide' : 'record-action-panel'}>
        {handle.props.children}
      </div>
      <RecordActionBehavior />
    </details>
  )
}
