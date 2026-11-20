import type { Handle } from 'remix/component'

/** Original artwork remains unchanged; a light backing preserves it in both themes. */
export function Brand(handle: Handle<{ href: string; class?: string }>) {
  return () => (
    <a href={handle.props.href} class={`brand-mark ${handle.props.class ?? ''}`} aria-label="BigBuck">
      <img class="brand-image" src="/bigbuck-mark.png" alt="" width="28" height="28" />
      <span class="word">BigBuck</span>
    </a>
  )
}
