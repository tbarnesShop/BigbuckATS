// Adds the shared edge secret to every request bound for the Rails API, when BIGBUCK_EDGE_SECRET is set.
// The API is reachable from the internet so the Vercel-hosted web app can call it; Rails refuses requests
// without this header (lib/request_security.rb). The web server imports this first, and the lab's CLI and
// MCP child processes load it with NODE_OPTIONS=--import, so every caller is covered without touching each
// fetch site. Without the variable this module does nothing (local development, tests).
const secret = process.env.BIGBUCK_EDGE_SECRET
const apiUrl = process.env.RAILS_API_URL ?? process.env.BIGBUCK_API_URL

if (secret && apiUrl && !globalThis.__bigbuckEdgeFetch) {
  const origin = new URL(apiUrl).origin
  const original = globalThis.fetch
  globalThis.__bigbuckEdgeFetch = true
  globalThis.fetch = (input, init) => {
    const url = typeof input === 'string' || input instanceof URL ? new URL(input) : new URL(input.url)
    if (url.origin !== origin) return original(input, init)
    const headers = new Headers(init?.headers ?? (input instanceof Request ? input.headers : undefined))
    headers.set('x-bigbuck-edge', secret)
    return original(input, { ...init, headers })
  }
}
