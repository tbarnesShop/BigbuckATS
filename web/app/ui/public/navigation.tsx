import { clientEntry, ref, type Handle, type RemixNode } from 'remix/component'

// Opening one transient control dismisses the other controls in the shared frame.
export const transientEvent = 'bigbuck:open-control'
export function openControl(source: Element) {
  document.dispatchEvent(new CustomEvent(transientEvent, { detail: source }))
}

export const CreateActions = clientEntry(
  import.meta.url,
  function CreateActions(handle: Handle<{ items: { href: string; label: string; hint: string }[] }>) {
    return () => (
      <details
        class="create-menu"
        mix={ref((details: HTMLDetailsElement, signal) => {
          const summary = details.querySelector('summary')!
          const close = () => {
            details.open = false
          }
          details.addEventListener(
            'toggle',
            () => {
              if (details.open) openControl(details)
            },
            { signal },
          )
          details.addEventListener(
            'keydown',
            (event) => {
              if (event.key !== 'Escape' || !details.open) return
              event.preventDefault()
              close()
              summary.focus({ preventScroll: true })
            },
            { signal },
          )
          details.addEventListener(
            'focusout',
            (event) => {
              if (!details.contains(event.relatedTarget as Node | null)) close()
            },
            { signal },
          )
          document.addEventListener(
            'pointerdown',
            (event) => {
              if (!details.contains(event.target as Node)) close()
            },
            { signal },
          )
          document.addEventListener(
            transientEvent,
            (event) => {
              if ((event as CustomEvent).detail !== details) close()
            },
            { signal },
          )
        })}
      >
        <summary class="btn btn-primary btn-small" role="button" aria-controls="create-menu-panel">
          + Create
        </summary>
        <nav id="create-menu-panel" aria-label="Create" class="create-menu-panel">
          {handle.props.items.map((item) => (
            <a key={item.href} class="create-menu-item" href={item.href}>
              <span>{item.label}</span>
              <span class="hint">{item.hint}</span>
            </a>
          ))}
        </nav>
      </details>
    )
  },
)

/** Native details provides navigation before hydration; dialog adds modal behavior. */
export const MobileNavigation = clientEntry(
  import.meta.url,
  function MobileNavigation(handle: Handle<{ children: RemixNode }>) {
    return () => (
      <details
        class="nav-drawer"
        mix={ref((details: HTMLDetailsElement, signal) => {
          const trigger = details.querySelector('summary')!
          const dialog = details.querySelector('dialog')!
          const closeButton = dialog.querySelector<HTMLButtonElement>('button')!
          // SSR's nonmodal open dialog is visible only inside the expanded disclosure.
          dialog.removeAttribute('open')
          details.dataset.enhanced = 'true'
          const desktop = matchMedia('(min-width: 769px)')
          const close = (returnFocus = true) => {
            if (dialog.open) dialog.close()
            details.open = false
            if (returnFocus && !desktop.matches) trigger.focus({ preventScroll: true })
          }
          details.addEventListener(
            'toggle',
            () => {
              if (details.open && !desktop.matches) {
                if (!dialog.open) {
                  openControl(details)
                  dialog.showModal()
                  closeButton.focus({ preventScroll: true })
                }
              } else if (dialog.open) close(false)
            },
            { signal },
          )
          closeButton.addEventListener('click', () => close(), { signal })
          dialog.addEventListener(
            'keydown',
            (event) => {
              if (event.key !== 'Tab') return
              const controls = Array.from(
                dialog.querySelectorAll<HTMLElement>(
                  'a[href], button, input, select, textarea, summary, [tabindex]',
                ),
              ).filter(
                (node) =>
                  node.tabIndex >= 0 && !node.hasAttribute('disabled') && node.getClientRects().length > 0,
              )
              const first = controls[0]
              const last = controls.at(-1)
              if (event.shiftKey && document.activeElement === first && last) {
                event.preventDefault()
                last.focus({ preventScroll: true })
              } else if (!event.shiftKey && document.activeElement === last && first) {
                event.preventDefault()
                first.focus({ preventScroll: true })
              }
            },
            { signal },
          )
          dialog.addEventListener(
            'cancel',
            (event) => {
              event.preventDefault()
              close()
            },
            { signal },
          )
          dialog.addEventListener(
            'click',
            (event) => {
              if (event.target !== dialog) return
              const bounds = dialog.getBoundingClientRect()
              if (
                event.clientX < bounds.left ||
                event.clientX > bounds.right ||
                event.clientY < bounds.top ||
                event.clientY > bounds.bottom
              )
                close()
            },
            { signal },
          )
          desktop.addEventListener(
            'change',
            () => {
              if (desktop.matches) close(false)
            },
            { signal },
          )
          signal.addEventListener(
            'abort',
            () => {
              if (dialog.open) dialog.close()
            },
            { once: true },
          )
        })}
      >
        <summary class="nav-menu-btn" role="button" aria-haspopup="dialog" aria-controls="mobile-navigation">
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            aria-hidden="true"
          >
            <path d="M4 7h16M4 12h16M4 17h16" />
          </svg>
          <span>Menu</span>
        </summary>
        <dialog
          id="mobile-navigation"
          class="nav-drawer-panel"
          aria-labelledby="mobile-navigation-title"
          open
        >
          <header class="nav-drawer-head">
            <h2 id="mobile-navigation-title" class="nav-drawer-title">
              Menu
            </h2>
            <button type="button" class="btn btn-ghost btn-small nav-drawer-close">
              Close
            </button>
          </header>
          {handle.props.children}
        </dialog>
      </details>
    )
  },
)
