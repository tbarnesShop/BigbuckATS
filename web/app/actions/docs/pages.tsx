import type { Handle } from 'remix/component'
import { Shell } from '../../ui/shell.tsx'
import { Brand } from '../../ui/brand.tsx'
import { ThemeToggle } from '../../ui/app-nav.tsx'
import { DocsNav, DocsArticle, DocsHeader } from './public/reader.tsx'

export function DocsPage(
  handle: Handle<{
    title: string
    slug: string
    html: string
    pages: Array<{ slug: string; title: string; group: string; searchText: string }>
    headings: Array<{ title: string; id: string }>
    previous?: { slug: string; title: string }
    next?: { slug: string; title: string }
  }>,
) {
  return () => {
    const p = handle.props
    return (
      <Shell title={`${p.title} · Docs`} bare>
        <div class="docs-root">
          <a class="skip-link" href="#main">
            Skip to content
          </a>
          <DocsHeader>
            <Brand href="/session" />
            <nav aria-label="Lab navigation">
              <a href="/session">Lab</a>
              <a href="/docs" aria-current="page">
                Docs
              </a>
            </nav>
            <ThemeToggle variant="bar" />
          </DocsHeader>
          <div class="docs-layout" data-outline={p.headings.length ? 'true' : 'false'}>
            <aside class="docs-sidebar">
              <h2 class="docs-sidebar-label">Developer docs</h2>
              <DocsNav pages={p.pages} current={p.slug} />
            </aside>
            <main id="main" class="docs-main" tabIndex={-1}>
              <p class="docs-breadcrumb">
                <a href="/docs">Docs</a> <span>/</span> {p.title}
              </p>
              <DocsArticle
                html={p.html}
                diagram={
                  p.slug === 'data-model' ? (
                    <div
                      class="docs-diagram"
                      role="img"
                      aria-label="An organization contains memberships and people. A membership owns agents. People connect to jobs through applications and to pools through memberships."
                    >
                      <div>Organization</div>
                      <span>↓</span>
                      <section>
                        <div>Membership → Agent</div>
                        <div>Person → Application → Job</div>
                        <div>Person → Pool membership → Pool</div>
                      </section>
                    </div>
                  ) : p.slug === 'agents' ? (
                    <div
                      class="docs-diagram"
                      role="img"
                      aria-label="A human membership owns an agent; the role and agent scopes bound its authority."
                    >
                      <div>Human + organization membership</div>
                      <span>↓ owns</span>
                      <div>Agent identity + scopes</div>
                      <span>↓ bounded by role, visibility, domain rules</span>
                      <div>Allowed action + attributable audit</div>
                    </div>
                  ) : p.slug === 'audit' ? (
                    <div
                      class="docs-diagram flow"
                      role="img"
                      aria-label="Credential to principal to authorization to domain transaction containing record, audit, and outbox."
                    >
                      <div>Credential</div>
                      <span>→</span>
                      <div>Principal</div>
                      <span>→</span>
                      <div>Authorize</div>
                      <span>→</span>
                      <div>Record + audit + outbox</div>
                    </div>
                  ) : null
                }
              />
              <nav class="docs-pagination" aria-label="Related chapters">
                {p.previous ? <a href={`/docs/${p.previous.slug}`}>← {p.previous.title}</a> : <span />}
                {p.next ? (
                  <a href={`/docs/${p.next.slug}`}>{p.next.title} →</a>
                ) : (
                  <a href="/session">Back to lab →</a>
                )}
              </nav>
              <p class="docs-footnote">
                A working proof of concept. Examples describe implementation behavior, not a compliance
                certification.
              </p>
            </main>
            {p.headings.length ? (
              <aside class="docs-outline" aria-label="Article outline">
                <p>On this page</p>
                {p.headings.map((heading) => (
                  <a key={heading.id} href={`#${heading.id}`}>
                    {heading.title}
                  </a>
                ))}
                <a class="docs-lab-link" href="/session">
                  Try something in the lab ↗
                </a>
              </aside>
            ) : null}
          </div>
        </div>
      </Shell>
    )
  }
}
