import { clientEntry, createMixin, on, type Handle } from 'remix/component'
import type { Mode, Surface } from '../../../data/lab/types.ts'

// Wrapped identities must not leave sticky navigation or anchors under the banner.
const measureBanner = createMixin<HTMLElement>(
  (handle) => {
    handle.addEventListener('insert', ({ node }) => {
      const frame = node.closest<HTMLElement>('.demo-frame')
      if (!frame) return
      const measure = () =>
        frame.style.setProperty('--demo-banner-height', `${node.getBoundingClientRect().height}px`)
      measure()
      const observer = new ResizeObserver(measure)
      observer.observe(node)
      handle.signal.addEventListener('abort', () => observer.disconnect(), { once: true })
    })
  },
  { ssr: false },
)

export const LiveBanner = clientEntry(
  import.meta.url,
  function LiveBanner(
    handle: Handle<{
      persona: string
      surface?: Surface
      sandbox?: Surface
      generation?: number
      resetsAt?: string
      mode?: Mode
      initialNow: number
    }>,
  ) {
    let now = handle.props.initialNow
    if (typeof window !== 'undefined' && handle.props.resetsAt) {
      const timer = setInterval(() => {
        if (document.visibilityState !== 'visible') return
        now = Date.now()
        handle.update()
      }, 1000)
      handle.signal.addEventListener('abort', () => clearInterval(timer), { once: true })
    }
    return () => {
      const p = handle.props
      const remaining = p.resetsAt ? Math.max(0, Math.ceil((Date.parse(p.resetsAt) - now) / 60000)) : null
      const expired = remaining === 0
      const context = new URLSearchParams({ surface: p.surface ?? 'ui', mode: p.mode ?? 'explore' })
      const reset = expired ? 'Workspace refreshing' : `Resets in ${resetIn(remaining ?? 0)}`
      return (
        <section class="demo-workspace-banner" aria-label="Demo workspace" mix={measureBanner()}>
          <div class="demo-workspace-identity">
            <strong>Demo workspace</strong>
            <span class="demo-workspace-persona">{p.persona}</span>
          </div>
          <div class="demo-workspace-desktop-meta">
            {remaining !== null ? <span>{reset}</span> : <span>Sample data</span>}
          </div>
          <nav class="demo-workspace-actions" aria-label="Demo controls">
            <a href={p.surface ? `/session?${context}` : '/session/login'}>
              {expired ? (
                'Start again'
              ) : (
                <>
                  <span class="demo-long">Change persona</span>
                  <span class="demo-short" aria-hidden="true">
                    Switch
                  </span>
                </>
              )}
            </a>
            <a
              class="demo-workspace-back"
              href={p.surface && p.surface !== 'ui' ? `/lab?${context}` : '/session'}
            >
              <span class="demo-long">Back to lab</span>
              <span class="demo-short" aria-hidden="true">
                Lab
              </span>{' '}
              <span aria-hidden="true">↗</span>
            </a>
            <details
              class="demo-workspace-details"
              mix={on('keydown', (event) => {
                if (event.key !== 'Escape') return
                const details = event.currentTarget as HTMLDetailsElement
                details.open = false
                details.querySelector('summary')?.focus({ preventScroll: true })
              })}
            >
              <summary>Details</summary>
              <div class="demo-workspace-details-panel">
                {remaining !== null ? <p>{reset}</p> : null}
                {p.sandbox ? null : <p>Sample data. Sign-in uses existing memberships only.</p>}
                <a href="/docs/permissions">Sandbox rules</a>
              </div>
            </details>
          </nav>
          <span class="visually-hidden" role="status">
            {expired ? 'Workspace refreshing. Choose Start again to resume.' : ''}
          </span>
        </section>
      )
    }
  },
)

/** 45 → "45 min", 130 → "2 h", 9912 → "7 days". */
export function resetIn(minutes: number): string {
  if (minutes < 60) return `${minutes} min`
  if (minutes < 48 * 60) return `${Math.round(minutes / 60)} h`
  return `${Math.round(minutes / (24 * 60))} days`
}
