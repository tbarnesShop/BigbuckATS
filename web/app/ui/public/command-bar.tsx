import { clientEntry, on, ref, type Handle } from 'remix/component'

import { routes } from '../../routes.ts'
import { openControl, transientEvent } from './navigation.tsx'

type Command = { id: string; label: string; hint: string; href: string; group: string }

/**
 * A plain GET search form. When the browser hydrates this island, ⌘K / Ctrl+K
 * focuses it and filters the same command list without a navigation.
 */
export const CommandBar = clientEntry(
  import.meta.url,
  function CommandBar(handle: Handle<{ commands: Command[] }>) {
    let open = false
    let query = ''
    let ready = false

    let root: HTMLDivElement
    const show = () => {
      openControl(root)
      open = true
      handle.update()
    }
    const close = () => {
      if (!open) return
      open = false
      handle.update()
    }

    return () => {
      let commands = handle.props.commands
      let needle = query.trim().toLowerCase()
      let shown = needle
        ? commands.filter((command) => `${command.label} ${command.hint}`.toLowerCase().includes(needle))
        : commands
      return (
        <div
          class="command-bar"
          mix={ref((node: HTMLDivElement, signal) => {
            root = node
            if (!ready) {
              ready = true
              const input = root.querySelector<HTMLInputElement>('input')
              query = input?.value ?? ''
              // Early typing/focus before enhancement must remain actionable once it loads.
              if (input === document.activeElement) {
                openControl(root)
                open = true
                handle.update()
              }
              root.dataset.enhanced = 'true'
            }
            document.addEventListener(
              'keydown',
              (event) => {
                if (!(event.metaKey || event.ctrlKey) || event.key.toLowerCase() !== 'k') return
                if (document.querySelector('dialog:modal')) return
                event.preventDefault()
                const input = root.querySelector('input')!
                input.focus({ preventScroll: true })
                input.select()
                show()
              },
              { signal },
            )
            document.addEventListener(
              'pointerdown',
              (event) => {
                if (!root.contains(event.target as Node)) close()
              },
              { signal },
            )
            document.addEventListener(
              transientEvent,
              (event) => {
                if ((event as CustomEvent).detail !== root) close()
              },
              { signal },
            )
            root.addEventListener(
              'focusout',
              (event) => {
                if (!root.contains(event.relatedTarget as Node | null)) close()
              },
              { signal },
            )
            root.addEventListener(
              'keydown',
              (event) => {
                if (event.key === 'Escape' && open) {
                  event.preventDefault()
                  root.querySelector('input')!.focus({ preventScroll: true })
                  close()
                } else if (event.key === 'ArrowDown' && event.target === root.querySelector('input')) {
                  const first = root.querySelector<HTMLAnchorElement>('.command-list a')
                  if (first) {
                    event.preventDefault()
                    first.focus({ preventScroll: true })
                  }
                }
              },
              { signal },
            )
          })}
        >
          <form method="get" action={routes.search.href()} role="search">
            <label class="command-label visually-hidden" htmlFor="command-q">
              Search or jump
            </label>
            <input
              id="command-q"
              name="q"
              type="search"
              placeholder="Search or jump"
              autoComplete="off"
              aria-keyshortcuts="Meta+K Control+K"
              aria-expanded={open ? 'true' : 'false'}
              aria-controls={open ? 'command-list' : undefined}
              mix={[
                on('input', (event) => {
                  query = (event.currentTarget as HTMLInputElement).value
                  show()
                }),
                on('focus', show),
              ]}
            />
            <button class="btn btn-ghost btn-small command-submit" type="submit" aria-label="Search">
              <span class="command-submit-label">Search</span>
              <svg
                class="command-submit-icon"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                aria-hidden="true"
                focusable="false"
              >
                <circle cx="10.5" cy="10.5" r="6.5" />
                <path d="m16 16 5 5" />
              </svg>
            </button>
            <kbd class="command-kbd">⌘K</kbd>
          </form>
          {open ? (
            <ul id="command-list" class="command-list" aria-label="Suggested destinations">
              {shown.length === 0 ? (
                <li class="command-empty">No commands match. Search still runs when you submit.</li>
              ) : (
                shown.slice(0, 8).map((command) => (
                  <li key={command.id}>
                    <a href={command.href}>
                      <span>{command.label}</span>
                      <span class="hint">{command.group}</span>
                    </a>
                  </li>
                ))
              )}
            </ul>
          ) : null}
        </div>
      )
    }
  },
)
