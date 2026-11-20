import { NotFoundPage } from './shell.tsx'

type Renderable = { url: URL; render?: (node: unknown, init?: ResponseInit) => Response }

/**
 * A styled 404 for a missing page or record (`Job not found`, `Person not found`), inside the app frame.
 * Falls back to plain text only when the render middleware has not run.
 */
export function notFound(
  context: unknown,
  props: { title?: string; message?: string; href?: string; linkLabel?: string } = {},
  init: ResponseInit = {},
): Response {
  const { url, render } = context as Renderable
  const status = init.status ?? 404
  if (!render) return new Response(props.title ?? `Not Found: ${url.pathname}`, { ...init, status })
  return render(<NotFoundPage {...props} />, { ...init, status })
}
