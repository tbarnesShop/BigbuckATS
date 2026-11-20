import type { Handle, RemixNode } from 'remix/component'

/** One destination in section tabs or filter segments. */
export type ChromeLink = {
  href: string
  label: string
  current?: boolean
  /** Shown muted beside the label (counts). */
  count?: number | string
  /** Quiet empty filters (stage groups with zero cards). */
  empty?: boolean
}

/** Read-only summary chips plus one optional secondary page action. */
export function PageSubhead(handle: Handle<{ label?: string; children?: RemixNode; action?: RemixNode }>) {
  return () => {
    let { label = 'Summary', children, action } = handle.props
    return (
      <div class="page-subhead">
        <div class="chip-row" role="group" aria-label={label}>
          {children}
        </div>
        {action ?? null}
      </div>
    )
  }
}

/** Peer views of a record or hub — underline tabs. */
export function SectionTabs(
  handle: Handle<{ label: string; links: ReadonlyArray<ChromeLink>; className?: string }>,
) {
  return () => {
    let { label, links, className } = handle.props
    if (links.length === 0) return null
    let classes = className ? `tabs ${className}` : 'tabs'
    return (
      <nav class={classes} aria-label={label}>
        {links.map((link) => (
          <a key={link.href} class="tab" href={link.href} aria-current={link.current ? 'page' : undefined}>
            {link.label}
            {link.count != null ? <span class="tab-count">{link.count}</span> : null}
          </a>
        ))}
      </nav>
    )
  }
}

/** Narrow what the current section shows — quiet segmented control. */
export function FilterSegments(handle: Handle<{ label: string; links: ReadonlyArray<ChromeLink> }>) {
  return () => {
    let { label, links } = handle.props
    if (links.length === 0) return null
    return (
      <nav class="filter-segments" aria-label={label}>
        {links.map((link) => (
          <a
            key={`${link.href}-${link.label}`}
            class="segment"
            href={link.href}
            aria-current={link.current ? 'page' : undefined}
            data-empty={link.empty ? '' : undefined}
          >
            {link.label}
            {link.count != null ? <span class="tab-count">{link.count}</span> : null}
          </a>
        ))}
      </nav>
    )
  }
}

/** Quiet prev / status / next for list pages — not tabs or filters. */
export function ListPagination(
  handle: Handle<{
    label?: string
    page: number
    pages: number
    prevHref?: string
    nextHref?: string
  }>,
) {
  return () => {
    let { label = 'Pages', page, pages, prevHref, nextHref } = handle.props
    if (pages <= 1) return null
    return (
      <nav class="list-pagination" aria-label={label}>
        {prevHref ? (
          <a class="page-link" href={prevHref}>
            Previous
          </a>
        ) : (
          <span class="page-link" aria-disabled="true">
            Previous
          </span>
        )}
        <span class="page-status" aria-current="page">
          Page {page} of {pages}
        </span>
        {nextHref ? (
          <a class="page-link" href={nextHref}>
            Next
          </a>
        ) : (
          <span class="page-link" aria-disabled="true">
            Next
          </span>
        )}
      </nav>
    )
  }
}
