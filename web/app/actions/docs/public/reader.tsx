import { clientEntry, on, ref, unsafeHTML, type Handle, type RemixNode } from 'remix/component'

type Page = { slug: string; title: string; group: string; searchText: string }
const references: Page[] = [
  {
    slug: 'reference/rest',
    title: 'REST / OpenAPI',
    group: 'Reference',
    searchText: 'HTTP contract endpoints',
  },
  { slug: 'reference/graphql', title: 'GraphQL', group: 'Reference', searchText: 'schema queries mutations' },
  { slug: 'reference/mcp', title: 'MCP', group: 'Reference', searchText: 'tools protocol' },
  { slug: 'reference/cli', title: 'CLI', group: 'Reference', searchText: 'commands terminal SDK' },
]

export const DocsHeader = clientEntry(
  import.meta.url,
  function DocsHeader(handle: Handle<{ children: RemixNode }>) {
    return () => (
      <header
        class="docs-header"
        mix={ref((header: HTMLElement, signal) => {
          const root = header.closest<HTMLElement>('.docs-root')!
          const measure = () =>
            root.style.setProperty('--docs-header-height', `${header.getBoundingClientRect().height}px`)
          measure()
          const observer = new ResizeObserver(measure)
          observer.observe(header)
          signal.addEventListener('abort', () => observer.disconnect(), { once: true })
        })}
      >
        {handle.props.children}
      </header>
    )
  },
)

export const DocsNav = clientEntry(
  import.meta.url,
  function DocsNav(handle: Handle<{ pages: Page[]; current: string }>) {
    let query = ''
    let root: HTMLDivElement
    const closeTopics = (returnFocus = false) => {
      const details = root.querySelector('details')!
      details.open = false
      if (returnFocus) details.querySelector('summary')!.focus({ preventScroll: true })
    }
    return () => {
      const p = handle.props
      const all = [...p.pages, ...references]
      const needle = query.trim().toLowerCase()
      const matches = all.filter((page) => `${page.title} ${page.searchText}`.toLowerCase().includes(needle))
      // While searching, pages whose title matches come first (and lead Enter); browsing keeps the groups.
      const found = needle
        ? [
            ...matches.filter((page) => page.title.toLowerCase().includes(needle)),
            ...matches.filter((page) => !page.title.toLowerCase().includes(needle)),
          ]
        : matches
      const current = all.find((page) => page.slug === p.current)?.title ?? 'Topics'
      const navigation = () => (
        <nav aria-label="Documentation">
          {found.map((page, i) => (
            <div key={page.slug}>
              {i === 0 || found[i - 1].group !== page.group ? <p class="docs-group">{page.group}</p> : null}
              <a aria-current={p.current === page.slug ? 'page' : undefined} href={`/docs/${page.slug}`}>
                {page.title}
              </a>
            </div>
          ))}
          {!found.length ? (
            <p class="docs-search-empty">No matching documentation. Try another term.</p>
          ) : null}
        </nav>
      )
      return (
        <div
          mix={ref((node: HTMLDivElement, signal) => {
            root = node
            const input = root.querySelector('input')!
            const details = root.querySelector('details')!
            const mobile = matchMedia('(max-width: 900px)')
            document.addEventListener(
              'keydown',
              (event) => {
                const active = document.activeElement
                if (
                  event.key !== '/' ||
                  event.metaKey ||
                  event.ctrlKey ||
                  event.altKey ||
                  active?.closest('input, textarea, select, [contenteditable]:not([contenteditable="false"])')
                )
                  return
                event.preventDefault()
                // An explicit search shortcut reveals the search controls, even after reading far down.
                input.focus()
                input.select()
                if (mobile.matches) details.open = true
              },
              { signal },
            )
            root.addEventListener(
              'keydown',
              (event) => {
                if (event.key !== 'Escape' || !details.open) return
                event.preventDefault()
                closeTopics(event.target !== input)
              },
              { signal },
            )
            root.addEventListener(
              'focusout',
              (event) => {
                // Only a keyboard move to somewhere else closes the panel. iOS Safari does not focus a tapped
                // link, so a tap on a result blurs the search box with no relatedTarget; closing then hid the
                // link before its click landed. Taps outside are handled by the pointerdown listener below.
                const next = event.relatedTarget as Node | null
                if (next && !root.contains(next)) closeTopics()
              },
              { signal },
            )
            document.addEventListener(
              'pointerdown',
              (event) => {
                if (!root.contains(event.target as Node)) closeTopics()
              },
              { signal },
            )
            mobile.addEventListener(
              'change',
              () => {
                if (!mobile.matches) closeTopics()
              },
              { signal },
            )
          })}
        >
          <label class="docs-search-label" for="docs-search">
            Search the docs <kbd aria-hidden="true">/</kbd>
          </label>
          <input
            id="docs-search"
            type="search"
            placeholder="Find a concept or reference…"
            autoComplete="off"
            aria-keyshortcuts="/"
            value={query}
            mix={[
              on('keydown', (event) => {
                // Enter opens the top match, so search works without reaching for the list. Read the
                // rendered list rather than a closure, which can hold an earlier render's results.
                if (event.key !== 'Enter') return
                const top = root.querySelector<HTMLAnchorElement>('.docs-topics-desktop nav a')
                if (!(event.target as HTMLInputElement).value.trim() || !top) return
                event.preventDefault()
                location.assign(top.href)
              }),
              on('input', (event) => {
                query = (event.target as HTMLInputElement).value
                if (matchMedia('(max-width: 900px)').matches) root.querySelector('details')!.open = true
                handle.update()
              }),
            ]}
            enterKeyHint="go"
          />
          <noscript>
            <p class="docs-search-empty">Browse Topics below. Search is available when JavaScript loads.</p>
          </noscript>
          <span class="visually-hidden" role="status">
            {query ? `${found.length} matching documentation topics.` : ''}
          </span>
          <div class="docs-topics-desktop">{navigation()}</div>
          <details class="docs-topics-mobile">
            <summary role="button">
              <strong>Topics</strong>
              <span class="docs-topic-context">{current}</span>
            </summary>
            <div class="docs-topic-panel">{navigation()}</div>
          </details>
        </div>
      )
    }
  },
)

export const DocsArticle = clientEntry(
  import.meta.url,
  function DocsArticle(handle: Handle<{ html: string; diagram?: RemixNode }>) {
    let status: HTMLSpanElement
    let latestCopy = 0
    const pending = new WeakSet<HTMLButtonElement>()
    return () => {
      const p = handle.props
      const intro = p.diagram ? (p.html.match(/^<h1[^>]*>[\s\S]*?<\/h1>\s*<p>[\s\S]*?<\/p>/)?.[0] ?? '') : ''
      return (
        <>
          <span
            class="visually-hidden"
            role="status"
            mix={ref((node: HTMLSpanElement) => {
              status = node
            })}
          />
          <div
            class="docs-prose"
            mix={on('click', async (event) => {
              const button = (event.target as HTMLElement).closest<HTMLButtonElement>('[data-copy-code]')
              if (!button || pending.has(button)) return
              pending.add(button)
              const attempt = ++latestCopy
              const text = button.closest('.docs-code')?.querySelector('code')?.textContent ?? ''
              button.setAttribute('aria-busy', 'true')
              try {
                await navigator.clipboard.writeText(text)
                if (handle.signal.aborted || !button.isConnected) return
                button.textContent = 'Copied'
                if (attempt === latestCopy) status.textContent = 'Code copied to clipboard.'
              } catch {
                if (handle.signal.aborted || !button.isConnected) return
                button.textContent = 'Copy failed'
                if (attempt === latestCopy)
                  status.textContent = 'Could not copy. Select the code and copy it manually.'
              } finally {
                pending.delete(button)
                button.removeAttribute('aria-busy')
              }
            })}
          >
            {intro ? <div innerHTML={unsafeHTML(intro)} /> : null}
            {p.diagram}
            <div innerHTML={unsafeHTML(p.html.slice(intro.length))} />
          </div>
        </>
      )
    }
  },
)
