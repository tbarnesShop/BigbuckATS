import { clearStoredDrafts, tabDraftStorage } from '../lab/public/drafts.ts'
import {
  detectMultipleImportMapSupport,
  importModule,
  preloadShim,
} from 'remix/multiple-import-maps-polyfill'
import { run } from 'remix/component'

// Use the documented document-navigation mode while hydrating client entries.
// Top-frame reconciliation in the current runtime throws on navigation and leaves
// stale content under the new URL, including after successful form submissions.
window.navigation?.addEventListener('navigate', (event) => event.stopImmediatePropagation())

const app = run({
  async loadModule(moduleUrl, exportName) {
    let mod = await importModule(moduleUrl)
    let Component = mod[exportName]
    if (typeof Component !== 'function') {
      throw new Error(`Unknown component: ${moduleUrl}#${exportName}`)
    }
    return Component
  },
  async processClientEntryPreloads(preloads) {
    if (await detectMultipleImportMapSupport()) return preloads

    preloadShim(preloads)
    return []
  },
})

// Filter, tab and view rows scroll sideways on narrow screens (kit.ts). Open each one with its current
// choice in view, so a selection past the right edge is never hidden. Rows that fit are left alone, and only
// the row scrolls, never the page.
function revealCurrentChoices() {
  for (const row of document.querySelectorAll<HTMLElement>(
    '.tabs, .filter-segments, .step-track, .list-pagination',
  )) {
    if (row.scrollWidth <= row.clientWidth + 1) continue
    const current = row.querySelector<HTMLElement>('[aria-current]')
    if (!current) continue
    const offset = current.getBoundingClientRect().left - row.getBoundingClientRect().left + row.scrollLeft
    row.scrollLeft = Math.max(0, offset - (row.clientWidth - current.offsetWidth) / 2)
  }
}
revealCurrentChoices()

if (import.meta.hot) {
  import.meta.hot.on('server:update', async () => {
    try {
      await app.ready()
      window.location.reload()
    } catch (error) {
      console.error('Error reloading top frame on server update', error)
    }
  })
}

// Sign-out may happen from any recruiter page, not just the lab.
document.addEventListener('submit', (event) => {
  if (event.defaultPrevented) return
  const form = event.target
  if (form instanceof HTMLFormElement && new FormData(form).get('intent') === 'sign-out') {
    clearStoredDrafts(tabDraftStorage())
    window.dispatchEvent(new Event('bigbuck:clear-lab-drafts'))
  }
})
