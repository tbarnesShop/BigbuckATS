import type { AppContext } from '../../router.ts'
import { getPersonDocument, sessionFromEnv, sessionFromRequest } from '../../data/api.ts'
import { signedIn } from '../../data/auth.ts'

/** Keep file access on the authenticated origin; never expose a storage URL or Rails credential. */
export async function personDocument(context: AppContext, personId: string, documentId: string) {
  const session = sessionFromRequest(context.url) ?? sessionFromEnv()
  if (!session) return new Response('Sign in to view this file.', { status: 401 })
  if (!signedIn()?.permissions?.includes('document.read'))
    return new Response('File not available.', { status: 403 })
  try {
    const response = await getPersonDocument(
      session,
      personId,
      documentId,
      context.url.searchParams.get('download') === 'true',
    )
    if (!response.ok)
      return new Response('File not available. Return to the person and refresh.', {
        status: response.status,
      })
    const headers = new Headers({ 'Cache-Control': 'private, no-store' })
    for (const name of ['Content-Type', 'Content-Disposition']) {
      const value = response.headers.get(name)
      if (value) headers.set(name, value)
    }
    return new Response(response.body, { headers })
  } catch {
    return new Response('File could not load. Return to the person and try again.', { status: 502 })
  }
}
