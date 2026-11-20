import type { Handle, RemixNode } from 'remix/component'

import { routes } from '../routes.ts'
import { Shell } from './shell.tsx'

/** Apply, schedule, and offer pages share the careers brand. */
export function CandidateFrame(
  handle: Handle<{
    title: string
    orgName?: string
    slug?: string
    careersHref?: string
    kicker?: string
    children?: RemixNode
  }>,
) {
  return () => {
    let { title, orgName = 'Big Buck', slug, kicker, children } = handle.props
    let careersHref =
      handle.props.careersHref ??
      (slug ? `${routes.careersIndex.href()}?slug=${encodeURIComponent(slug)}` : routes.careersIndex.href())
    return (
      <Shell title={title} bare>
        <div class="candidate-frame">
          <header class="candidate-brand">
            <a class="candidate-word" href={careersHref}>
              {orgName}
            </a>
            {kicker ? <p class="candidate-sub">{kicker}</p> : null}
          </header>
          <div class="candidate-main">
            <h1>{title}</h1>
            {children}
          </div>
        </div>
      </Shell>
    )
  }
}
