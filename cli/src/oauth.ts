import { createHash } from 'node:crypto'
import { execFile } from 'node:child_process'
import { createServer } from 'node:http'
import type { AddressInfo } from 'node:net'
import { promisify } from 'node:util'
import { mkdir, writeFile, lstat } from 'node:fs/promises'
import { homedir } from 'node:os'
import { join } from 'node:path'
import lockfile from 'proper-lockfile'
import * as oidc from 'openid-client'

export type OauthSettings = {
  issuer: string
  clientId: string
  apiUrl: string
  audience?: string
  resource?: string
  scopes: string
  callbackPort: number
}
export type StoredTokens = { accessToken: string; refreshToken?: string; expiresAt: number; subject?: string }
export type TokenStore = {
  read(): Promise<StoredTokens | null>; write(value: StoredTokens): Promise<void>; clear(): Promise<void>
  locked<T>(work: () => Promise<T>): Promise<T>
}
type Tokens = Awaited<ReturnType<typeof oidc.authorizationCodeGrant>>
const exec = promisify(execFile)

function httpsUrl(value: string, label: string): URL {
  const url = new URL(value)
  if (url.protocol !== 'https:' || url.username || url.password || url.hash || url.search) {
    throw new Error(`${label} must be an HTTPS URL without credentials, query, or fragment`)
  }
  return url
}

export function settingsFromEnv(apiOverride?: string, env: NodeJS.ProcessEnv = process.env): OauthSettings {
  if (!env.BIGBUCK_OAUTH_ISSUER || !env.BIGBUCK_OAUTH_CLIENT_ID) {
    throw new Error('Set BIGBUCK_OAUTH_ISSUER and BIGBUCK_OAUTH_CLIENT_ID for OAuth login')
  }
  httpsUrl(env.BIGBUCK_OAUTH_ISSUER, 'OAuth issuer')
  const issuer = env.BIGBUCK_OAUTH_ISSUER
  const api = new URL(apiOverride ?? env.BIGBUCK_API_URL ?? env.RAILS_API_URL ?? 'http://127.0.0.1:3000')
  if (api.username || api.password || api.search || api.hash ||
    (api.protocol !== 'https:' && !(api.protocol === 'http:' && ['127.0.0.1', '[::1]'].includes(api.hostname)))) {
    throw new Error('The API must use HTTPS (HTTP is allowed only for a loopback development API)')
  }
  const callbackPort = Number(env.BIGBUCK_OAUTH_CALLBACK_PORT ?? '0')
  if (!Number.isInteger(callbackPort) || callbackPort < 0 || callbackPort > 65535) throw new Error('Invalid OAuth callback port')
  return { issuer, clientId: env.BIGBUCK_OAUTH_CLIENT_ID, apiUrl: api.href.replace(/\/$/, ''),
    audience: env.BIGBUCK_OAUTH_AUDIENCE, resource: env.BIGBUCK_OAUTH_RESOURCE,
    scopes: env.BIGBUCK_OAUTH_SCOPES ?? 'people:read jobs:read', callbackPort }
}

export function keychainAccount(settings: OauthSettings): string {
  return createHash('sha256').update(JSON.stringify(settings)).digest('hex')
}

export async function sessionLock<T>(account: string, work: () => Promise<T>,
  directory = join(process.env.XDG_STATE_HOME ?? join(homedir(), '.local', 'state'), 'bigbuck')): Promise<T> {
  if (!/^[a-f0-9]{64}$/.test(account)) throw new Error('Invalid session lock identity')
  await mkdir(directory, { recursive: true, mode: 0o700 })
  const path = join(directory, `${account}.session`)
  try { await writeFile(path, '', { flag: 'wx', mode: 0o600 }) }
  catch (error) { if ((error as NodeJS.ErrnoException).code !== 'EEXIST') throw error }
  if (!(await lstat(path)).isFile()) throw new Error('Unsafe session lock file')
  const release = await lockfile.lock(path, { stale: 300_000, update: 10_000,
    retries: { retries: 30, minTimeout: 100, maxTimeout: 1000 } })
  try { return await work() } finally { await release() }
}

export async function keychainStore(settings: OauthSettings): Promise<TokenStore> {
  // Native keychain calls keep credentials out of files and process arguments.
  // Loading is lazy so headless client-credentials jobs need no desktop keyring.
  const { AsyncEntry } = await import('@napi-rs/keyring')
  const entry = new AsyncEntry('dev.bigbuck.cli.oauth', keychainAccount(settings),
    { linux: { store: 'secret-service' } })
  return {
    async read() {
      const raw = await entry.getPassword()
      if (raw === null) return null
      const value: unknown = JSON.parse(raw)
      if (!value || typeof value !== 'object' || !('accessToken' in value) || typeof value.accessToken !== 'string' ||
        !('expiresAt' in value) || typeof value.expiresAt !== 'number' || !Number.isFinite(value.expiresAt) ||
        ('refreshToken' in value && typeof value.refreshToken !== 'string') ||
        ('subject' in value && typeof value.subject !== 'string')) throw new Error('Invalid keychain session; run bigbuck auth logout and login again')
      return value as StoredTokens
    },
    async write(value) { await entry.setPassword(JSON.stringify(value)) },
    async clear() { await entry.deleteCredential() },
    locked(work) { return sessionLock(keychainAccount(settings), work) },
  }
}

export async function provider(settings: OauthSettings, clientSecret?: string): Promise<oidc.Configuration> {
  return oidc.discovery(new URL(settings.issuer), settings.clientId,
    { token_endpoint_auth_method: clientSecret ? 'client_secret_basic' : 'none' },
    clientSecret ? oidc.ClientSecretBasic(clientSecret) : oidc.None(),
    { timeout: 10, execute: [oidc.enableNonRepudiationChecks] })
}

function resourceParameters(settings: OauthSettings): Record<string, string> {
  return { ...(settings.audience ? { audience: settings.audience } : {}), ...(settings.resource ? { resource: settings.resource } : {}) }
}

function stored(tokens: Tokens, old?: StoredTokens): StoredTokens {
  if (tokens.token_type.toLowerCase() !== 'bearer' || typeof tokens.expires_in !== 'number' ||
    !Number.isFinite(tokens.expires_in) || tokens.expires_in <= 0 || tokens.expires_in > 900) {
    throw new Error('Provider must issue Bearer access tokens with an expiry of at most 15 minutes')
  }
  const subject = tokens.claims()?.sub ?? old?.subject
  if (old?.subject && subject !== old.subject) throw new Error('Provider changed the signed-in identity during renewal')
  return { accessToken: tokens.access_token, refreshToken: tokens.refresh_token ?? old?.refreshToken,
    expiresAt: Date.now() + tokens.expires_in * 1000, subject }
}

export async function verifyApiIdentity(settings: OauthSettings, token: string): Promise<unknown> {
  // Do not follow redirects with credentials or accept a successful HTML login page.
  const response = await fetch(`${settings.apiUrl}/v1/sessions/current`, {
    headers: { Authorization: `Bearer ${token}`, Accept: 'application/json', 'X-Bigbuck-Surface': 'cli' },
    redirect: 'error', signal: AbortSignal.timeout(10_000),
  })
  if (!response.ok) throw new Error(`Big Buck rejected OAuth access (${response.status}); verify the API audience and provisioned identity`)
  return response.json()
}

export async function loopbackReceiver(port = 0, timeoutMs = 180_000) {
  let resolve!: (url: URL) => void
  let reject!: (error: Error) => void
  let expectedState = ''
  let settled = false
  const callback = new Promise<URL>((yes, no) => { resolve = yes; reject = no })
  // A browser launch can fail before anyone awaits the receiver.
  void callback.catch(() => {})
  const server = createServer((request, response) => {
    let url: URL
    try { url = new URL(request.url ?? '/', redirectUri) } catch {
      response.writeHead(400, { 'Cache-Control': 'no-store' }).end('Invalid login callback')
      return
    }
    if (url.origin !== new URL(redirectUri).origin || request.method !== 'GET' || request.headers.host !== new URL(redirectUri).host ||
      url.pathname !== '/oauth/callback' || !expectedState || url.searchParams.getAll('state').length !== 1 ||
      url.searchParams.get('state') !== expectedState || settled) {
      response.writeHead(400, { 'Cache-Control': 'no-store' }).end('Invalid login callback')
      return
    }
    settled = true
    response.writeHead(200, { 'Content-Type': 'text/plain', 'Cache-Control': 'no-store',
      'Content-Security-Policy': "default-src 'none'", 'Referrer-Policy': 'no-referrer' })
      .end('Login callback received. Return to the terminal to confirm the result.')
    resolve(url)
  })
  let redirectUri = ''
  await new Promise<void>((yes, no) => {
    server.once('error', no)
    server.listen(port, '127.0.0.1', () => yes())
  })
  redirectUri = `http://127.0.0.1:${(server.address() as AddressInfo).port}/oauth/callback`
  const timer = setTimeout(() => { reject(new Error('OAuth login timed out')); server.close(); server.closeAllConnections() }, timeoutMs)
  return { redirectUri, callback, expectState(state: string) { expectedState = state },
    close() { clearTimeout(timer); server.close(); server.closeAllConnections() } }
}

export async function openBrowser(url: string): Promise<void> {
  if (process.platform === 'darwin') await exec('open', [url])
  else if (process.platform === 'win32') {
    // Direct executable invocation, without a command shell.
    await exec('rundll32.exe', ['url.dll,FileProtocolHandler', url])
  } else await exec('xdg-open', [url])
}

export async function login(settings: OauthSettings, store: TokenStore, options: {
  config?: oidc.Configuration; open?: (url: string) => Promise<void>; verify?: typeof verifyApiIdentity
} = {}): Promise<unknown> {
  const config = options.config ?? await provider(settings)
  const receiver = await loopbackReceiver(settings.callbackPort)
  try {
    const state = oidc.randomState()
    const nonce = oidc.randomNonce()
    const verifier = oidc.randomPKCECodeVerifier()
    receiver.expectState(state)
    const url = oidc.buildAuthorizationUrl(config, { redirect_uri: receiver.redirectUri,
      scope: [...new Set(['openid', 'offline_access', ...settings.scopes.split(/\s+/)])].join(' '),
      state, nonce, code_challenge: await oidc.calculatePKCECodeChallenge(verifier), code_challenge_method: 'S256',
      ...resourceParameters(settings) })
    await (options.open ?? openBrowser)(url.href)
    const callback = await receiver.callback
    const tokens = await oidc.authorizationCodeGrant(config, callback, {
      pkceCodeVerifier: verifier, expectedState: state, expectedNonce: nonce, idTokenExpected: true,
    }, resourceParameters(settings))
    const value = stored(tokens)
    const identity = await (options.verify ?? verifyApiIdentity)(settings, value.accessToken)
    await store.locked(() => store.write(value))
    return identity
  } finally { receiver.close() }
}

export async function accessToken(settings: OauthSettings, store: TokenStore, config?: oidc.Configuration): Promise<string> {
  return store.locked(async () => {
  const old = await store.read()
  if (!old) throw new Error('Run bigbuck auth login first')
  if (old.expiresAt > Date.now() + 60_000) return old.accessToken
  if (!old.refreshToken) throw new Error('Session expired; run bigbuck auth login')
  const resolved = config ?? await provider(settings)
  try {
    const tokens = await oidc.refreshTokenGrant(resolved, old.refreshToken, resourceParameters(settings))
    const value = stored(tokens, old)
    await verifyApiIdentity(settings, value.accessToken)
    // Persist a rotated refresh token before using the new access token.
    await store.write(value)
    return value.accessToken
  } catch (error) {
    if (error instanceof oidc.ResponseBodyError && error.error === 'invalid_grant') await store.clear()
    throw new Error('OAuth renewal failed; retry or run bigbuck auth login')
  }
  })
}

export async function logout(settings: OauthSettings, store: TokenStore, config?: oidc.Configuration): Promise<void> {
  return store.locked(async () => {
  const tokens = await store.read()
  if (!tokens) return
  try {
    const resolved = config ?? await provider(settings)
    if (!resolved.serverMetadata().revocation_endpoint) throw new Error('Provider has no token revocation endpoint')
    if (tokens.refreshToken) await oidc.tokenRevocation(resolved, tokens.refreshToken, { token_type_hint: 'refresh_token' })
    await oidc.tokenRevocation(resolved, tokens.accessToken, { token_type_hint: 'access_token' })
  } catch {
    throw new Error('Local session removed, but provider revocation failed. Revoke the grant in your identity provider; access tokens can remain valid until expiry.')
  } finally { await store.clear() }
  })
}

// Reuse short-lived machine tokens within a command and coalesce concurrent requests.
export function serviceTokenProvider(settings: OauthSettings, secret: string, config?: oidc.Configuration): () => Promise<string> {
  let cached: StoredTokens | undefined
  let pending: Promise<string> | undefined
  let resolved = config
  return async () => {
    if (cached && cached.expiresAt > Date.now() + 60_000) return cached.accessToken
    if (!pending) pending = (async () => {
      resolved ??= await provider(settings, secret)
      cached = stored(await oidc.clientCredentialsGrant(resolved, {
        scope: settings.scopes, ...resourceParameters(settings),
      }))
      return cached.accessToken
    })().finally(() => { pending = undefined })
    return pending
  }
}
