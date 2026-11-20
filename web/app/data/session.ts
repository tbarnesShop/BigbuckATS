import { signedIn } from './auth.ts'

/**
 * Query string carried on in-app links. Identity is never part of it (that lives
 * in the session cookie); only the public careers slug is passed along.
 */
export function orgQuery(url: URL): string {
  const slug = url.searchParams.get('slug')
  return slug ? `?${new URLSearchParams({ slug })}` : ''
}

export function careersSlugFrom(url: URL): string | null {
  return url.searchParams.get('slug') ?? signedIn()?.organizationSlug ?? process.env.BIGBUCK_ORG_SLUG ?? 'big-buck'
}

/** Short chrome label for whoever is signed in. */
export function sessionHintFrom(_url?: URL): string | undefined {
  const current = signedIn()
  if (!current) return undefined
  const who = current.email ?? current.name ?? 'Signed in'
  return current.actingAgentName ? `${who} · acting as ${current.actingAgentName}` : who
}
