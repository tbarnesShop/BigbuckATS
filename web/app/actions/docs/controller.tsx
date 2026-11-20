import { createController } from 'remix/router'
import { routes } from '../../routes.ts'
import { article, chapters, docsIndex, reference } from '../../data/docs.ts'
import { DocsPage } from './pages.tsx'
const pages = () =>
  docsIndex().map(({ slug, title, group, searchText }) => ({ slug, title, group, searchText }))
export const docsIndexController = createController(
  { docsIndex: routes.docsIndex },
  {
    actions: {
      docsIndex() {
        return new Response(null, { status: 302, headers: { Location: '/docs/start' } })
      },
    },
  },
)
export const docsController = createController(
  { docsPage: routes.docsPage },
  {
    actions: {
      docsPage(context) {
        const page = article(context.params.slug)
        if (!page) return new Response('Documentation page not found', { status: 404 })
        const index = chapters.findIndex((p) => p.slug === page.slug)
        return context.render(
          <DocsPage {...page} pages={pages()} previous={chapters[index - 1]} next={chapters[index + 1]} />,
        )
      },
    },
  },
)
export const docsReferenceController = createController(
  { docsReference: routes.docsReference },
  {
    actions: {
      docsReference(context) {
        const page = reference(context.params.kind)
        if (!page) return new Response('Reference not found', { status: 404 })
        return context.render(
          <DocsPage
            {...page}
            slug={`reference/${context.params.kind}`}
            pages={pages()}
            headings={page.headings}
          />,
        )
      },
    },
  },
)
