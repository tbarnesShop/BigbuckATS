import { orgQuery } from './session.ts'

const LIST_PARAMS: Record<string, readonly string[]> = {
  '/people': ['q', 'lifecycle_stage', 'project_id', 'slug'],
  '/applications': ['job_id', 'stage', 'page', 'slug'],
  '/search': ['q', 'slug'],
}

/** Only list destinations and their known filters can be carried through a record. */
export function listReturn(value: string | null | undefined): string | undefined {
  if (!value || !value.startsWith('/') || value.startsWith('//')) return undefined
  try {
    const url = new URL(value, 'https://bigbuck.invalid')
    const keys = LIST_PARAMS[url.pathname]
    if (url.origin !== 'https://bigbuck.invalid' || !keys) return undefined
    const params = new URLSearchParams()
    for (const key of keys) {
      const entry = url.searchParams.get(key)
      if (entry) params.set(key, entry)
    }
    return `${url.pathname}${params.size ? `?${params}` : ''}`
  } catch {
    return undefined
  }
}

export function recordHref(path: string, query: string, returnTo?: string): string {
  const params = new URLSearchParams(query.startsWith('?') ? query.slice(1) : query)
  const safeReturn = listReturn(returnTo)
  params.delete('return_to')
  if (safeReturn) params.set('return_to', safeReturn)
  return `${path}${params.size ? `?${params}` : ''}`
}

export function recordQuery(url: URL): string {
  return recordHref('', orgQuery(url), url.searchParams.get('return_to') ?? undefined)
}

export function returnLabel(returnTo: string): string {
  return returnTo.startsWith('/applications')
    ? 'Applications'
    : returnTo.startsWith('/search')
      ? 'Search results'
      : 'People'
}
